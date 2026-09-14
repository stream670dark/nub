const std = @import("std");
const Token = @import("Token.zig");
const Ast = @import("Ast.zig");
const Lexer = @import("Lexer.zig");
const Evaluator = @import("Evaluator.zig");

lexer: Lexer,
ast: Ast,
variables: std.StringHashMap(Ast.NodeIndex),

const ParseError = error{
    UnexpectedToken,
    UndefinedVariable,
    OutOfMemory,
} || std.fmt.ParseIntError;

pub fn init(allocator: std.mem.Allocator, source: []const u8) @This() {
    return .{
        .lexer = Lexer.init(source),
        .ast = Ast.init(allocator),
        .variables = std.StringHashMap(Ast.NodeIndex).init(allocator),
    };
}

pub fn parse(self: *@This()) !void {
    defer self.ast.deinit();
    defer self.variables.deinit();
    while (self.lexer.peekToken() != .nub_eof) {
        const token = self.lexer.peekToken();
        switch (token) {
            .nub_var => {
                _ = self.lexer.nextToken();
                const name = self.lexer.nextToken();
                _ = self.lexer.nextToken();
                const expr = try self.parseExpression(0);
                try self.expect(.nub_semicolon);
                _ = try self.ast.addNode(.{
                    .variable = .{
                        .name = name.lexeme,
                        .kind = null,
                        .value = expr,
                    },
                });
                try self.variables.put(name.lexeme, expr);
            },
            .nub_int, .nub_id => {
                const tree = try self.parseExpression(0);
                _ = Evaluator.evaluate(&self.ast, tree);
            },

            .nub_print => {
                _ = self.lexer.nextToken();
                const expr = try self.parseExpression(0);
                try self.expect(.nub_semicolon);
                const node = try self.ast.addNode(.{ .print = expr });
                _ = Evaluator.evaluate(&self.ast, node);
            },
            .nub_if => {
                const tree = try self.parseExpression(0);
                _ = Evaluator.evaluate(&self.ast, tree);
            },
            else => {
                _ = self.lexer.nextToken();
            },
        }
    }
}

fn getBindingPower(kind: Token.Kind) ?u8 {
    return switch (kind) {
        .nub_equals, .nub_not_equals, .nub_greater_than, .nub_less_than, .nub_greater_equals, .nub_less_equals => 1,
        .nub_plus, .nub_minus => 2,
        .nub_asterisk, .nub_slash => 3,
        else => null,
    };
}

fn parsePrimary(self: *@This()) ParseError!Ast.NodeIndex {
    const token = self.lexer.nextToken();

    switch (token.kind) {
        .nub_int => {
            const value = try std.fmt.parseInt(i64, token.lexeme, 10);
            return try self.ast.addNode(.{ .type = .{ .int = value } });
        },
        .nub_id => {
            const node_index = self.variables.get(token.lexeme) orelse return error.UndefinedVariable;
            return node_index;
        },
        .nub_string => {
            return try self.ast.addNode(.{ .type = .{ .string = token.lexeme } });
        },
        .nub_bool => {
            const value = std.mem.eql(u8, token.lexeme, "true");
            return try self.ast.addNode(.{ .type = .{ .boolean = value } });
        },
        .nub_if => {
            try self.expect(.nub_lparen);
            const condition = try self.parseExpression(0);
            try self.expect(.nub_rparen);
            const then_branch = try self.parseExpression(0);

            var else_branch: ?Ast.NodeIndex = null;
            if (self.lexer.peekToken() == .nub_else) {
                try self.expect(.nub_else);
                else_branch = try self.parseExpression(0);
            }

            return try self.ast.addNode(.{
                .if_expr = .{
                    .condition = condition,
                    .then_branch = then_branch,
                    .else_branch = else_branch,
                },
            });
        },
        .nub_print => {
            const expr = try self.parseExpression(0);
            return try self.ast.addNode(.{ .print = expr });
        },
        else => return error.UnexpectedToken,
    }
}

fn parseExpression(self: *@This(), min_bp: u8) ParseError!Ast.NodeIndex {
    var left = try self.parsePrimary();

    while (true) {
        const next_token_kind = self.lexer.peekToken();

        const bp = getBindingPower(next_token_kind) orelse break;

        if (bp <= min_bp) break;

        const op = self.lexer.nextToken();

        const right = try self.parseExpression(bp);

        left = try self.ast.addNode(.{
            .binary_op = .{
                .left = left,
                .op = op.kind,
                .right = right,
            },
        });
    }

    return left;
}

fn parseStatement(self: *@This()) ParseError!Ast.NodeIndex {
    const token = self.lexer.peekToken();
    return switch (token) {
        .nub_print => {
            _ = self.lexer.nextToken();
            const expr = try self.parseExpression(0);
            try self.expect(.nub_semicolon);
            return try self.ast.addNode(.{ .print = expr });
        },
        else => {
            const expr = try self.parseExpression(0);
            try self.expect(.nub_semicolon);
            return expr;
        },
    };
}

fn expect(self: *@This(), kind: Token.Kind) !void {
    const token = self.lexer.nextToken();
    if (token.kind != kind) return error.UnexpectedToken;
}
