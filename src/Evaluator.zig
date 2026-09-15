// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Ast = @import("Ast.zig");

pub fn evaluate(ast: *Ast, index: Ast.NodeIndex, env: *std.StringHashMap(Ast.Value)) Ast.Value {
    return switch (ast.nodes.items[index]) {
        .type => |val| val,
        .unary_op => |op| {
            const expr = evaluate(ast, op.expr, env);
            return switch (op.op) {
                .nub_minus => .{ .int = -expr.int },
                else => unreachable,
            };
        },
        .binary_op => |op| {
            const left = evaluate(ast, op.left, env);
            const right = evaluate(ast, op.right, env);
            return switch (op.op) {
                .nub_plus => return .{ .int = left.int + right.int },
                .nub_minus => return .{ .int = left.int - right.int },
                .nub_asterisk => return .{ .int = left.int * right.int },
                .nub_slash => .{
                    .int = blk: {
                        const remainder = @rem(left.int, right.int);
                        if (remainder != 0) std.debug.print("warn: {d} / {d} result is rounded\n", .{ left.int, right.int });
                        var result = @divTrunc(left.int, right.int);
                        const abs_rem = if (remainder < 0) -remainder else remainder;
                        const abs_div = if (right.int < 0) -right.int else right.int;
                        if (abs_rem * 2 >= abs_div) result += if ((left.int < 0) != (right.int < 0)) -1 else 1;
                        break :blk result;
                    },
                },
                .nub_equals => .{ .boolean = left.int == right.int },
                .nub_not_equals => .{ .boolean = left.int != right.int },
                .nub_less_than => .{ .boolean = left.int < right.int },
                .nub_greater_than => .{ .boolean = left.int > right.int },
                .nub_less_equals => .{ .boolean = left.int <= right.int },
                .nub_greater_equals => .{ .boolean = left.int >= right.int },
                else => unreachable,
            };
        },
        .variable => |expr| {
            const value = evaluate(ast, expr.value, env);
            env.put(expr.name, value) catch unreachable;
            return .{ .none = {} };
        },
        .identifier => |name| {
            const value = env.get(name) orelse unreachable;
            return value;
        },
        .discard => |expr| {
            _ = evaluate(ast, expr, env);
            return .{ .none = {} };
        },
        .print => |expr| {
            const value = evaluate(ast, expr, env);
            switch (value) {
                .int => |v| std.debug.print("{d}\n", .{v}),
                .string => |v| std.debug.print("{s}\n", .{v}),
                .boolean => |v| std.debug.print("{}", .{v}),
                .none => |v| std.debug.print("{any}", .{v}),
            }
            return .{ .none = {} };
        },
        .if_expr => |i| {
            const condition = evaluate(ast, i.condition, env);
            if (condition != .boolean) unreachable;
            if (condition.boolean) {
                return evaluate(ast, i.then_branch, env);
            } else if (i.else_branch) |branch| {
                return evaluate(ast, branch, env);
            }
            return .{ .none = {} };
        },
        .block => |b| {
            var last_value: Ast.Value = .{ .none = {} };
            for (b.statements) |stmt| {
                last_value = evaluate(ast, stmt, env);
            }
            return last_value;
        },
    };
}
