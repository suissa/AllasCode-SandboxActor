const std = @import("std");
const zeroize = @import("zeroize.zig");

pub const Terminal = enum { ok, error_terminal };

/// Runtime-owned persistence hooks. SandboxActor never emits terminal Ok before
/// serialize + commit have succeeded.
pub fn CommitBarrier(comptime Context: type) type {
    return struct {
        context: *Context,
        serializeFn: *const fn (*Context, std.mem.Allocator) anyerror![]u8,
        commitFn: *const fn (*Context, []const u8) anyerror!void,

        pub fn commit(self: @This(), allocator: std.mem.Allocator) !void {
            var serialized = try self.serializeFn(self.context, allocator);
            defer {
                zeroize.secure(serialized);
                allocator.free(serialized);
            }
            try self.commitFn(self.context, serialized);
        }
    };
}

/// Executes the terminal sequence. The caller may emit Ok only when this
/// function returns .ok.
pub fn finalize(
    barrier: anytype,
    allocator: std.mem.Allocator,
    transient_memory: []u8,
) Terminal {
    barrier.commit(allocator) catch {
        zeroize.secure(transient_memory);
        return .error_terminal;
    };

    zeroize.secure(transient_memory);
    return .ok;
}
