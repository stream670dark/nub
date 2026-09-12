// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Token = @import("Token.zig");

const raw_source = "  var x = 10 + 4 * 2 x + 2 / 4 * x";

pub const Ast = struct {
    nodes: std.ArrayList(NodeKind),
    allocator: std.mem.Allocator,

    pub const NodeIndex = u32;

    pub const NodeKind = union(enum) {
        variable: Variable,
        int_literal: i64,
        binary_op: BinaryOp,
        print: NodeIndex,
    };

    pub const BinaryOp = struct {
        left: NodeIndex,
        op: Token.Kind,
        right: NodeIndex,
    };

    pub const Variable = struct {
        name: []const u8,
        kind: ?[]const u8,
        value: NodeIndex,
    };

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .nodes = .empty,
            .allocator = allocator,
        };
    }

    pub fn addNode(self: *@This(), node: NodeKind) !NodeIndex {
        const index = self.nodes.items.len;
        try self.nodes.append(self.allocator, node);
        return @intCast(index);
    }

    pub fn deinit(self: *@This()) void {
        self.nodes.deinit(self.allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    var parser = Parser.init(init.gpa, raw_source);
    try parser.parse();
}

pub const Parser = struct {
    lexer: Lexer,
    ast: Ast,
    variables: std.StringHashMap(Ast.NodeIndex),

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        return .{
            .lexer = Lexer.init(source),
            .ast = Ast.init(allocator),
            .variables = std.StringHashMap(Ast.NodeIndex).init(allocator),
        };
    }

    pub fn parse(self: *Parser) !void {
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
                    const result = evaluate(&self.ast, tree);
                    std.debug.print("result: {d}\n", .{result});
                },
                else => {
                    _ = self.lexer.nextToken();
                },
            }
        }
    }

    fn getBindingPower(kind: Token.Kind) ?u8 {
        return switch (kind) {
            .nub_plus, .nub_minus => 1,
            .nub_asterisk, .nub_slash => 2,
            else => null,
        };
    }

    fn parsePrimary(self: *Parser) !Ast.NodeIndex {
        const token = self.lexer.nextToken();

        switch (token.kind) {
            .nub_int => {
                const value = try std.fmt.parseInt(i64, token.lexeme, 10);
                return try self.ast.addNode(.{ .int_literal = value });
            },
            .nub_id => {
                const node_index = self.variables.get(token.lexeme) orelse return error.UndefinedVariable;
                return node_index;
            },
            else => return error.UnexpectedToken,
        }
    }

    fn parseExpression(self: *Parser, min_bp: u8) !Ast.NodeIndex {
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

    fn evaluate(ast: *Ast, index: Ast.NodeIndex) i64 {
        return switch (ast.nodes.items[index]) {
            .int_literal => |val| val,
            .binary_op => |op| {
                const left = evaluate(ast, op.left);
                const right = evaluate(ast, op.right);
                switch (op.op) {
                    .nub_plus => return left + right,
                    .nub_minus => return left - right,
                    .nub_asterisk => return left * right,
                    .nub_slash => {
                        const remaider = @rem(left, right);
                        if (@rem(left, right) != 0) std.debug.print("warn: {d} / {d} result is rounded\n", .{ left, right });
                        var result = @divTrunc(left, right);
                        const abs_rem = if (remaider < 0) -remaider else remaider;
                        const abs_div = if (right < 0) -right else right;
                        if (abs_rem * 2 >= abs_div) result += if ((left < 0) != (right < 0)) -1 else 1;
                        return result;
                    },
                    else => unreachable,
                }
            },
            .variable => |v| evaluate(ast, v.value),
            else => unreachable,
        };
    }
};

const Lexer = struct {
    source: []const u8,
    cursor: usize,

    pub fn init(lexer_source: []const u8) Lexer {
        return .{
            .source = lexer_source,
            .cursor = 0,
        };
    }

    pub fn nextToken(self: *@This()) Token {
        self.skipWhitespace();

        if (self.source.len <= self.cursor) return .{
            .kind = .nub_eof,
            .lexeme = "",
        };

        var token: Token = undefined;

        const char = self.source[self.cursor];
        if (std.ascii.isAlphabetic(char)) token = self.readWord();
        if (std.ascii.isDigit(char)) token = self.readNumber();

        if (!std.ascii.isAlphanumeric(char)) token = self.readSymbol();

        return token;
    }

    pub fn peekToken(self: @This()) Token.Kind {
        var copy = self;

        copy.skipWhitespace();

        if (copy.source.len <= copy.cursor) return .nub_eof;
        var token: Token = undefined;

        const char = copy.source[copy.cursor];
        if (std.ascii.isAlphabetic(char)) token = copy.readWord();
        if (std.ascii.isDigit(char)) token = copy.readNumber();

        if (!std.ascii.isAlphanumeric(char)) token = copy.readSymbol();

        return token.kind;
    }

    fn readSymbol(self: *@This()) Token {
        const start = self.cursor;
        var token: Token = undefined;
        switch (self.source[start]) {
            '+' => token = .{
                .kind = .nub_plus,
                .lexeme = "+",
            },
            '-' => token = .{
                .kind = .nub_minus,
                .lexeme = "-",
            },
            '*' => token = .{
                .kind = .nub_asterisk,
                .lexeme = "*",
            },
            '/' => token = .{
                .kind = .nub_slash,
                .lexeme = "/",
            },
            '=' => token = .{
                .kind = .nub_equals,
                .lexeme = "=",
            },
            else => token = .{
                .kind = .nub_unknown,
                .lexeme = "",
            },
        }

        self.cursor += 1;
        return token;
    }

    fn readNumber(self: *@This()) Token {
        const start = self.cursor;

        while (self.source.len > self.cursor and std.ascii.isDigit(self.source[self.cursor])) {
            self.cursor += 1;
        }

        const lexeme = self.source[start..self.cursor];

        return .{
            .kind = .nub_int,
            .lexeme = lexeme,
        };
    }

    fn readWord(self: *@This()) Token {
        const start = self.cursor;

        while (self.source.len > self.cursor and std.ascii.isAlphanumeric(self.source[self.cursor])) {
            self.cursor += 1;
        }

        const lexeme = self.source[start..self.cursor];

        return .{
            .kind = keyword.get(lexeme) orelse .nub_id,
            .lexeme = lexeme,
        };
    }

    fn skipWhitespace(self: *@This()) void {
        while (self.source.len > self.cursor and std.ascii.isWhitespace(self.source[self.cursor])) {
            self.cursor += 1;
        }
    }
};

const keyword = std.StaticStringMap(Token.Kind).initComptime(.{
    .{ "var", .nub_var },
    .{ "print", .nub_print },
});
