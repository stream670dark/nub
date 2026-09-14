const std = @import("std");
const Token = @import("Token.zig");

nodes: std.ArrayList(NodeKind),
allocator: std.mem.Allocator,

pub const NodeIndex = u32;

pub const NodeKind = union(enum) {
    type: Value,
    variable: Variable,
    binary_op: BinaryOp,
    print: NodeIndex,
    if_expr: IfExpr,
};

pub const IfExpr = struct {
    condition: NodeIndex,
    then_branch: NodeIndex,
    else_branch: ?NodeIndex,
};

pub const Value = union(enum) {
    int: i64,
    string: []const u8,
    boolean: bool,
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
