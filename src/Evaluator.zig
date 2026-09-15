// Copyright (c) 2026 stream670dark.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

const std = @import("std");
const Ast = @import("Ast.zig");

pub fn evaluate(ast: *Ast, index: Ast.NodeIndex, env: *std.StringHashMap(Ast.Value)) !Ast.Value {
    return switch (ast.nodes.items[index]) {
        .type => |val| val,
        .unary_op => |op| {
            const expr = try evaluate(ast, op.expr, env);
            return switch (op.op) {
                .nub_minus => switch (expr) {
                    .int => |v| .{ .int = -v },
                    .float => |v| .{ .float = -v },
                    else => unreachable,
                },
                else => unreachable,
            };
        },
        .binary_op => |op| {
            const left = try evaluate(ast, op.left, env);
            const right = try evaluate(ast, op.right, env);
            return switch (op.op) {
                .nub_plus => switch (left) {
                    .int => |l_val| {
                        switch (right) {
                            .int => |r_val| return .{
                                .int = l_val + r_val,
                            },
                            else => unreachable,
                        }
                    },
                    .float => |l_val| {
                        switch (right) {
                            .float => |r_val| return .{
                                .float = l_val + r_val,
                            },
                            else => unreachable,
                        }
                    },
                    .string => |l_val| {
                        switch (right) {
                            .string => |r_val| return .{
                                .string = try std.mem.concat(env.allocator, u8, &.{ l_val, r_val }),
                            },
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                },
                .nub_minus => switch (left) {
                    .int => |l_val| {
                        switch (right) {
                            .int => |r_val| return .{
                                .int = l_val - r_val,
                            },
                            else => unreachable,
                        }
                    },
                    .float => |l_val| {
                        switch (right) {
                            .float => |r_val| return .{
                                .float = l_val - r_val,
                            },
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                },
                .nub_asterisk => switch (left) {
                    .int => |l_val| {
                        switch (right) {
                            .int => |r_val| return .{
                                .int = l_val * r_val,
                            },
                            else => unreachable,
                        }
                    },
                    .float => |l_val| {
                        switch (right) {
                            .float => |r_val| return .{
                                .float = l_val * r_val,
                            },
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                },
                .nub_slash => switch (left) {
                    .int => |l_val| {
                        switch (right) {
                            .int => |r_val| return .{ .int = blk: {
                                const remainder = @rem(l_val, r_val);
                                if (remainder != 0) std.debug.print("warn: {d} / {d} result is rounded\n", .{ l_val, r_val });
                                var result = @divTrunc(l_val, r_val);
                                const abs_rem = if (remainder < 0) -remainder else remainder;
                                const abs_div = if (r_val < 0) -r_val else r_val;
                                if (abs_rem * 2 >= abs_div) result += if ((l_val < 0) != (r_val < 0)) -1 else 1;
                                break :blk result;
                            } },
                            else => unreachable,
                        }
                    },
                    .float => |l_val| {
                        switch (right) {
                            .float => |r_val| return .{
                                .float = l_val / r_val,
                            },
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                },
                .nub_less_than => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val < r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val < r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = (std.mem.order(u8, l_val, r_val) == .lt),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                .nub_greater_than => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val > r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val > r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = (std.mem.order(u8, l_val, r_val) == .gt),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                .nub_less_equals => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val <= r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val <= r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = (std.mem.order(u8, l_val, r_val) == .eq or std.mem.order(u8, l_val, r_val) == .lt),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                .nub_greater_equals => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val >= r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val >= r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = (std.mem.order(u8, l_val, r_val) == .eq or std.mem.order(u8, l_val, r_val) == .gt),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                .nub_equals => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val == r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val == r_val },
                        else => unreachable,
                    },
                    .boolean => |l_val| switch (right) {
                        .boolean => |r_val| .{ .boolean = l_val == r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = std.mem.eql(u8, l_val, r_val),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                .nub_not_equals => switch (left) {
                    .int => |l_val| switch (right) {
                        .int => |r_val| .{ .boolean = l_val != r_val },
                        else => unreachable,
                    },
                    .float => |l_val| switch (right) {
                        .float => |r_val| .{ .boolean = l_val != r_val },
                        else => unreachable,
                    },
                    .boolean => |l_val| switch (right) {
                        .boolean => |r_val| .{ .boolean = l_val != r_val },
                        else => unreachable,
                    },
                    .string => |l_val| switch (right) {
                        .string => |r_val| .{
                            .boolean = !std.mem.eql(u8, l_val, r_val),
                        },
                        else => unreachable,
                    },
                    else => unreachable,
                },
                else => unreachable,
            };
        },
        .variable => |expr| {
            const value = try evaluate(ast, expr.value, env);
            env.put(expr.name, value) catch unreachable;
            return .{ .none = {} };
        },
        .reassign => |r| {
            const target_node = ast.nodes.items[r.target];
            if (target_node != .identifier) unreachable;

            const name = target_node.identifier;

            if (!env.contains(name)) unreachable;

            const new_value = try evaluate(ast, r.value, env);
            env.put(name, new_value) catch unreachable;

            return .{ .none = {} };
        },
        .identifier => |name| {
            const value = env.get(name) orelse unreachable;
            return value;
        },
        .discard => |expr| {
            _ = try evaluate(ast, expr, env);
            return .{ .none = {} };
        },
        .print => |expr| {
            const value = try evaluate(ast, expr, env);
            switch (value) {
                .int => |v| std.debug.print("{d}\n", .{v}),
                .float => |v| std.debug.print("{d}\n", .{v}),
                .string => |v| std.debug.print("{s}\n", .{v}),
                .boolean => |v| std.debug.print("{}\n", .{v}),
                .none => |v| std.debug.print("{any}\n", .{v}),
            }
            return .{ .none = {} };
        },
        .if_expr => |i| {
            const condition = try evaluate(ast, i.condition, env);
            if (condition != .boolean) unreachable;
            if (condition.boolean) {
                return try evaluate(ast, i.then_branch, env);
            } else if (i.else_branch) |branch| {
                return try evaluate(ast, branch, env);
            }
            return .{ .none = {} };
        },
        .while_expr => |w| {
            while (true) {
                const condition = try evaluate(ast, w.condition, env);
                if (condition != .boolean) unreachable;
                if (!condition.boolean) break;
                _ = try evaluate(ast, w.body, env);
                if (w.continue_expr) |c_expr| {
                    _ = try evaluate(ast, c_expr, env);
                }
            }
            return .{ .none = {} };
        },
        .block => |b| {
            var last_value: Ast.Value = .{ .none = {} };
            for (b.statements) |stmt| {
                last_value = try evaluate(ast, stmt, env);
            }
            return last_value;
        },
    };
}
