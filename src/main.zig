// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Parser = @import("Parser.zig");

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
