const std = @import("std");

/// Writes through volatile memory so the compiler cannot elide the wipe.
pub fn secure(bytes: []u8) void {
    for (bytes) |*b| {
        @as(*volatile u8, @ptrCast(b)).* = 0;
    }
    std.mem.doNotOptimizeAway(bytes.ptr);
}

test "secure zeroization" {
    var buf = [_]u8{ 1, 2, 3, 4 };
    secure(&buf);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0 }, &buf);
}
