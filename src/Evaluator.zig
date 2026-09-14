const std = @import("std");
const Ast = @import("Ast.zig");

pub fn evaluate(ast: *Ast, index: Ast.NodeIndex) Ast.Value {
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
                .nub_equals => .{ .boolean = left == right },
                .nub_not_equals => .{ .boolean = left != right },
                .nub_less_than => .{ .boolean = left < right },
                .nub_greater_than => .{ .boolean = left > right },
                .nub_less_equals => .{ .boolean = left <= right },
                .nub_greater_equals => .{ .boolean = left >= right },
                else => unreachable,
            };
        },
        .variable => |v| evaluate(ast, v.value),
        .print => |expr| {
            const value = evaluate(ast, expr);
            switch (value) {
                .int => |v| std.debug.print("{d}\n", .{v}),
                .string => |v| std.debug.print("{s}\n", .{v}),
                .boolean => |v| std.debug.print("{}", .{v}),
            }
            return value;
        },
        .if_expr => |i| {
            const condition = evaluate(ast, i.condition);
            if (condition != .boolean) unreachable;
            if (condition.boolean) {
                return evaluate(ast, i.then_branch);
            } else if (i.else_branch) |branch| {
                return evaluate(ast, branch);
            }
            return .{ .boolean = false };
        },
        // else => unreachable,
    };
}
