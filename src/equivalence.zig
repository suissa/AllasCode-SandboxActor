const std = @import("std");

/// Many input keys -> one canonical result identifier.
/// This stores the result only once; aliases store only the canonical ID.
pub const EquivalenceIndex = struct {
    allocator: std.mem.Allocator,
    aliases: std.StringHashMap([]const u8),
    results: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) EquivalenceIndex {
        return .{
            .allocator = allocator,
            .aliases = std.StringHashMap([]const u8).init(allocator),
            .results = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *EquivalenceIndex) void {
        var ait = self.aliases.iterator();
        while (ait.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        var rit = self.results.iterator();
        while (rit.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.aliases.deinit();
        self.results.deinit();
    }

    pub fn putGroup(
        self: *EquivalenceIndex,
        group_id: []const u8,
        values: []const []const u8,
        result: []const u8,
    ) !void {
        if (!self.results.contains(group_id)) {
            try self.results.put(
                try self.allocator.dupe(u8, group_id),
                try self.allocator.dupe(u8, result),
            );
        }

        for (values) |value| {
            if (self.aliases.contains(value)) continue;
            try self.aliases.put(
                try self.allocator.dupe(u8, value),
                try self.allocator.dupe(u8, group_id),
            );
        }
    }

    pub fn get(self: *const EquivalenceIndex, value: []const u8) ?[]const u8 {
        const group = self.aliases.get(value) orelse return null;
        return self.results.get(group);
    }
};

test "many values point to one result" {
    var idx = EquivalenceIndex.init(std.testing.allocator);
    defer idx.deinit();

    const values = [_][]const u8{ "val1", "val2", "val3" };
    try idx.putGroup("g1", &values, "result");
    try std.testing.expectEqualStrings("result", idx.get("val2").?);
}
