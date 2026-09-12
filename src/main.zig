// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Token = @import("Token.zig");

pub const Ast = struct {
    nodes: std.ArrayList(NodeKind),
    allocator: std.mem.Allocator,

    pub const NodeIndex = u32;

    pub const NodeKind = union(enum) {
        type: Value,
        variable: Variable,
        binary_op: BinaryOp,
        print: NodeIndex,
    };

    pub const Value = union(enum) {
        int: i64,
        string: []const u8,
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
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();

    _ = args.skip();

    const filepath = args.next() orelse {
        std.log.err("usage: nub <file.nub>", .{});
        return;
    };

    if (!std.mem.endsWith(u8, filepath, ".nub")) {
        std.log.err("'{s}' is not a .nub file", .{filepath});
        return;
    }

    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, filepath, init.gpa, .unlimited);
    defer init.gpa.free(source);

    var parser = Parser.init(init.gpa, source);
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
                    _ = evaluate(&self.ast, tree);
                },

                .nub_print => {
                    _ = self.lexer.nextToken();
                    //_ = self.lexer.nextToken(); TODO
                    const expr = try self.parseExpression(0);
                    //_ = self.lexer.nextToken(); TODO
                    const node = try self.ast.addNode(.{ .print = expr });
                    _ = evaluate(&self.ast, node);
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
                return try self.ast.addNode(.{ .type = .{ .int = value } });
            },
            .nub_id => {
                const node_index = self.variables.get(token.lexeme) orelse return error.UndefinedVariable;
                return node_index;
            },
            .nub_string => {
                return try self.ast.addNode(.{ .type = .{ .string = token.lexeme } });
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

    fn evaluate(ast: *Ast, index: Ast.NodeIndex) Ast.Value {
        return switch (ast.nodes.items[index]) {
            .type => |val| val,
            .binary_op => |op| {
                const left = evaluate(ast, op.left).int;
                const right = evaluate(ast, op.right).int;
                return switch (op.op) {
                    .nub_plus => return .{ .int = left + right },
                    .nub_minus => return .{ .int = left - right },
                    .nub_asterisk => return .{ .int = left * right },
                    .nub_slash => .{
                        .int = blk: {
                            const remainder = @rem(left, right);
                            if (remainder != 0) std.debug.print("warn: {d} / {d} result is rounded\n", .{ left, right });
                            var result = @divTrunc(left, right);
                            const abs_rem = if (remainder < 0) -remainder else remainder;
                            const abs_div = if (right < 0) -right else right;
                            if (abs_rem * 2 >= abs_div) result += if ((left < 0) != (right < 0)) -1 else 1;
                            break :blk result;
                        },
                    },

                    else => unreachable,
                };
            },
            .variable => |v| evaluate(ast, v.value),
            .print => |expr| {
                const value = evaluate(ast, expr);
                switch (value) {
                    .int => |v| std.debug.print("{d}\n", .{v}),
                    .string => |v| std.debug.print("{s}\n", .{v}),
                }
                return value;
            },
            // else => unreachable,
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
                .kind = .nub_assign,
                .lexeme = "=",
            },
            // ';' => token = .{
            //     .kind = .nub_semicolon,
            //     .lexeme = ";",
            // }, TODO
            '"' => {
                self.cursor += 1;
                return self.readString();
            },
            else => token = .{
                .kind = .nub_unknown,
                .lexeme = "",
            },
        }

        self.cursor += 1;
        return token;
    }

    fn readString(self: *@This()) Token {
        const start = self.cursor;

        while (self.source.len > self.cursor and self.source[self.cursor] != '"') {
            self.cursor += 1;
        }

        const lexeme = self.source[start..self.cursor];
        self.cursor += 1;

        return .{
            .kind = .nub_string,
            .lexeme = lexeme,
        };
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
