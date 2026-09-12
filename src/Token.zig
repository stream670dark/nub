// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

pub const Kind = enum {
    nub_var,
    nub_const,
    nub_id,
    nub_int,
    nub_string,

    nub_type,

    nub_plus,
    nub_minus,
    nub_assign,
    nub_asterisk,
    nub_slash,
    nub_semicolon,

    nub_print,

    nub_eof,
    nub_unknown,
};

kind: Kind,
lexeme: []const u8,
