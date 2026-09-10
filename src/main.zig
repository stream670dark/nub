// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Token = @import("Token.zig");

const source = "  1 + 2 + 2 - 1";

pub const Ast = struct {
    nodes: std.ArrayList(NodeKind),
    allocator: std.mem.Allocator,

    pub const NodeIndex = u32;

    pub const NodeKind = union(enum) {
        variable: Variable,
        int_literal: i64,
        binary_op: BinaryOp,
    };

    pub const BinaryOp = struct {
        left: NodeIndex,
        op: []const u8,
        right: NodeIndex,
    };

    pub const Variable = struct {
        name: []const u8,
        kind: ?[]const u8,
        value: ?[]const u8,
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
    try parse(init.gpa);
}

pub fn parse(allocator: std.mem.Allocator) !void {
    var lexer = Lexer.init(source);
    var ast = Ast.init(allocator);
    defer ast.deinit();
    var token = lexer.nextToken();
    while (token.kind != .nub_eof) {
        switch (token.kind) {
            .nub_var => {
                //TODO
            },
            .nub_int => {
                var left_val = try ast.addNode(.{ .int_literal = try std.fmt.parseInt(i64, token.lexeme, 10) });

                while ((lexer.peekToken() == .nub_plus) or (lexer.peekToken() == .nub_minus)) {
                    const op = lexer.nextToken();

                    const val = lexer.nextToken();
                    const right_val = try ast.addNode(.{ .int_literal = try std.fmt.parseInt(i64, val.lexeme, 10) });

                    const node = try ast.addNode(.{
                        .binary_op = .{
                            .left = left_val,
                            .op = op.lexeme,
                            .right = right_val,
                        },
                    });

                    var result: u32 = undefined;

                    switch (ast.nodes.items[node]) {
                        .binary_op => {
                            switch (op.kind) {
                                .nub_plus => result = try ast.addNode(.{ .int_literal = ast.nodes.items[left_val].int_literal + ast.nodes.items[right_val].int_literal }),
                                .nub_minus => result = try ast.addNode(.{ .int_literal = ast.nodes.items[left_val].int_literal - ast.nodes.items[right_val].int_literal }),
                                else => unreachable,
                            }
                        },
                        else => unreachable,
                    }

                    std.debug.print("{d} {s} {d} -> {d}\n", .{ ast.nodes.items[left_val].int_literal, ast.nodes.items[node].binary_op.op, ast.nodes.items[right_val].int_literal, ast.nodes.items[result].int_literal });

                    left_val = result;
                }
            },
            else => {},
        }
        token = lexer.nextToken();
    }
}

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
});
