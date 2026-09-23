const std = @import("std");

const c = @cImport({
    @cInclude("time.h");
});

pub const Sample = struct {
    cpu_ns: u64,
    wall_ns: u64,
};

fn ns(ts: c.struct_timespec) u64 {
    return @as(u64, @intCast(ts.tv_sec)) * std.time.ns_per_s +
        @as(u64, @intCast(ts.tv_nsec));
}

/// Measures local CPU and wall time for one deterministic benchmark iteration.
/// External I/O should not be included in a deterministic CPU budget.
pub fn measure(comptime F: type, f: F) !Sample {
    var cpu_before: c.struct_timespec = undefined;
    var cpu_after: c.struct_timespec = undefined;
    var wall_before: c.struct_timespec = undefined;
    var wall_after: c.struct_timespec = undefined;

    if (c.clock_gettime(c.CLOCK_PROCESS_CPUTIME_ID, &cpu_before) != 0)
        return error.ClockFailed;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &wall_before) != 0)
        return error.ClockFailed;

    try f();

    if (c.clock_gettime(c.CLOCK_PROCESS_CPUTIME_ID, &cpu_after) != 0)
        return error.ClockFailed;
    if (c.clock_gettime(c.CLOCK_MONOTONIC, &wall_after) != 0)
        return error.ClockFailed;

    return .{
        .cpu_ns = ns(cpu_after) - ns(cpu_before),
        .wall_ns = ns(wall_after) - ns(wall_before),
    };
}
