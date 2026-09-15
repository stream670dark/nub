// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Token = @import("Token.zig");

source: []const u8,
cursor: usize,

pub fn init(lexer_source: []const u8) @This() {
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
        '=' => {
            if (self.cursor + 1 < self.source.len and self.source[self.cursor + 1] == '=') {
                self.cursor += 1;
                token = .{
                    .kind = .nub_equals,
                    .lexeme = "==",
                };
            } else {
                token = .{
                    .kind = .nub_assign,
                    .lexeme = "=",
                };
            }
        },
        ';' => token = .{
            .kind = .nub_semicolon,
            .lexeme = ";",
        },
        '"' => {
            self.cursor += 1;
            return self.readString();
        },
        '(' => token = .{
            .kind = .nub_lparen,
            .lexeme = "(",
        },
        ')' => token = .{
            .kind = .nub_rparen,
            .lexeme = ")",
        },
        '{' => token = .{
            .kind = .nub_lbrace,
            .lexeme = "{",
        },
        '}' => token = .{
            .kind = .nub_rbrace,
            .lexeme = "}",
        },
        '>' => {
            if (self.cursor + 1 < self.source.len and self.source[self.cursor + 1] == '=') {
                self.cursor += 1;
                token = .{
                    .kind = .nub_greater_equals,
                    .lexeme = ">=",
                };
            } else {
                token = .{
                    .kind = .nub_greater_than,
                    .lexeme = ">",
                };
            }
        },
        '<' => {
            if (self.cursor + 1 < self.source.len and self.source[self.cursor + 1] == '=') {
                self.cursor += 1;
                token = .{
                    .kind = .nub_less_equals,
                    .lexeme = "<=",
                };
            } else {
                token = .{
                    .kind = .nub_less_than,
                    .lexeme = "<",
                };
            }
        },
        '!' => {
            if (self.cursor + 1 < self.source.len and self.source[self.cursor + 1] == '=') {
                self.cursor += 1;
                token = .{ .kind = .nub_not_equals, .lexeme = "!=" };
            } else {
                token = .{ .kind = .nub_unknown, .lexeme = "!" };
            }
        },
        '_' => {
            token = .{
                .kind = .nub_discard,
                .lexeme = "_",
            };
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

    while (self.source.len > self.cursor and (std.ascii.isAlphanumeric(self.source[self.cursor]) or self.source[self.cursor] == '_')) {
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

const keyword = std.StaticStringMap(Token.Kind).initComptime(.{
    .{ "var", .nub_var },
    .{ "print", .nub_print },
    .{ "if", .nub_if },
    .{ "else", .nub_else },
    .{ "true", .nub_bool },
    .{ "false", .nub_bool },
});
