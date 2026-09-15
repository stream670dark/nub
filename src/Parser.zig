// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Token = @import("Token.zig");
const Ast = @import("Ast.zig");
const Lexer = @import("Lexer.zig");
const Evaluator = @import("Evaluator.zig");

lexer: Lexer,
ast: Ast,

const ParseError = error{
    UnexpectedToken,
    UndefinedVariable,
    OutOfMemory,
} || std.fmt.ParseIntError;

pub fn init(allocator: std.mem.Allocator, source: []const u8) @This() {
    return .{
        .lexer = Lexer.init(source),
        .ast = Ast.init(allocator),
    };
}

pub fn parse(self: *@This(), env: *std.StringHashMap(Ast.Value)) !void {
    defer self.ast.deinit();
    while (self.lexer.peekToken() != .nub_eof) {
        const node = try self.parseStatement();
        _ = try Evaluator.evaluate(&self.ast, node, env);
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
        .nub_float => {
            const value = try std.fmt.parseFloat(f64, token.lexeme);
            return try self.ast.addNode(.{ .type = .{ .float = value } });
        },
        .nub_id => {
            return try self.ast.addNode(.{ .identifier = token.lexeme });
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
            const then_branch =
                if (self.lexer.peekToken() == .nub_lbrace)
                    try self.parseBlock()
                else
                    try self.parseExpression(0);

            var else_branch: ?Ast.NodeIndex = null;
            if (self.lexer.peekToken() == .nub_else) {
                try self.expect(.nub_else);
                else_branch =
                    if (self.lexer.peekToken() == .nub_lbrace)
                        try self.parseBlock()
                    else
                        try self.parseExpression(0);
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
        .nub_minus => {
            const expr = try self.parseExpression(100);
            return try self.ast.addNode(.{
                .unary_op = .{
                    .op = .nub_minus,
                    .expr = expr,
                },
            });
        },
        .nub_while => {
            try self.expect(.nub_lparen);
            const condition = try self.parseExpression(0);
            try self.expect(.nub_rparen);

            var continue_expr: ?Ast.NodeIndex = null;
            if (self.lexer.peekToken() == .nub_colon) {
                try self.expect(.nub_colon);
                try self.expect(.nub_lparen);
                const target = try self.parseExpression(0);

                if (self.lexer.peekToken() == .nub_assign) {
                    try self.expect(.nub_assign);
                    const value = try self.parseExpression(0);
                    continue_expr = try self.ast.addNode(.{
                        .reassign = .{
                            .target = target,
                            .value = value,
                        },
                    });
                } else {
                    continue_expr = target;
                }

                try self.expect(.nub_rparen);
            }

            const body = try self.parseBlock();

            return try self.ast.addNode(.{
                .while_expr = .{
                    .condition = condition,
                    .continue_expr = continue_expr,
                    .body = body,
                },
            });
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
        .nub_var => {
            try self.expect(.nub_var);
            const name = self.lexer.nextToken();
            try self.expect(.nub_assign);
            const expr = try self.parseExpression(0);
            try self.expect(.nub_semicolon);
            const node = try self.ast.addNode(.{
                .variable = .{
                    .name = name.lexeme,
                    .kind = null,
                    .value = expr,
                },
            });
            return node;
        },
        .nub_print => {
            _ = self.lexer.nextToken();
            const expr = try self.parseExpression(0);
            try self.expect(.nub_semicolon);
            const node = try self.ast.addNode(.{ .print = expr });
            return node;
        },
        .nub_discard => {
            try self.expect(.nub_discard);
            try self.expect(.nub_assign);
            const expr = try self.parseExpression(0);
            try self.expect(.nub_semicolon);
            return try self.ast.addNode(.{ .discard = expr });
        },
        else => {
            const expr = try self.parseExpression(0);

            if (self.lexer.peekToken() == .nub_assign) {
                try self.expect(.nub_assign);
                const value = try self.parseExpression(0);
                try self.expect(.nub_semicolon);

                return try self.ast.addNode(.{
                    .reassign = .{
                        .target = expr,
                        .value = value,
                    },
                });
            }

            try self.expect(.nub_semicolon);
            return expr;
        },
    };
}

fn parseBlock(self: *@This()) ParseError!Ast.NodeIndex {
    try self.expect(.nub_lbrace);
    var statements: std.ArrayList(Ast.NodeIndex) = .empty;
    defer statements.deinit(self.ast.allocator);
    while (self.lexer.peekToken() != .nub_rbrace) {
        if (self.lexer.peekToken() == .nub_eof) break;
        try statements.append(self.ast.allocator, try self.parseStatement());
    }

    try self.expect(.nub_rbrace);

    const nodes = try statements.toOwnedSlice(self.ast.allocator);

    return self.ast.addNode(.{ .block = .{ .statements = nodes } });
}

fn expect(self: *@This(), kind: Token.Kind) !void {
    const token = self.lexer.nextToken();
    if (token.kind != kind) return error.UnexpectedToken;
}
