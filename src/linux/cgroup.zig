const std = @import("std");

pub const Limits = struct {
    memory_bytes: u64,
    cpu_millicores: u32,
};

fn writeValue(dir: std.fs.Dir, path: []const u8, value: []const u8) !void {
    var file = try dir.createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(value);
}

/// Applies hard cgroup v2 limits to an already-created delegated cgroup.
/// SandboxActor deliberately does not create privileged cgroup hierarchies.
/// The embedding service may delegate one cgroup directory per worker.
pub fn apply(allocator: std.mem.Allocator, cgroup_path: []const u8, limits: Limits) !void {
    var dir = try std.fs.openDirAbsolute(cgroup_path, .{});
    defer dir.close();

    const mem = try std.fmt.allocPrint(allocator, "{d}\n", .{limits.memory_bytes});
    defer allocator.free(mem);
    try writeValue(dir, "memory.max", mem);

    // cpu.max is "quota period" in microseconds.
    const period_us: u64 = 100_000;
    const quota_us: u64 = @max(@as(u64, 1_000), (period_us * limits.cpu_millicores) / 1000);
    const cpu = try std.fmt.allocPrint(allocator, "{d} {d}\n", .{ quota_us, period_us });
    defer allocator.free(cpu);
    try writeValue(dir, "cpu.max", cpu);

    // Move current worker into the delegated cgroup.
    try writeValue(dir, "cgroup.procs", "0\n");
}
