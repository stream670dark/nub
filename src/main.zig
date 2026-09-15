// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Parser = @import("Parser.zig");
const Ast = @import("Ast.zig");

pub fn main(init: std.process.Init) !void {
    const ArenaAllocator = init.arena;
    var args = try init.minimal.args.iterateAllocator(ArenaAllocator.allocator());

    _ = args.skip();

    const filepath = args.next() orelse {
        std.log.err("usage: nub <file.nub>", .{});
        return;
    };

    if (!std.mem.endsWith(u8, filepath, ".nub")) {
        std.log.err("'{s}' is not a .nub file", .{filepath});
        return;
    }

    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, filepath, ArenaAllocator.allocator(), .unlimited);

    var parser = Parser.init(ArenaAllocator.allocator(), source);
    var env = std.StringHashMap(Ast.Value).init(ArenaAllocator.allocator());
    try parser.parse(&env);
}
