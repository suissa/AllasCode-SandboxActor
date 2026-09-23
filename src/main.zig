const std = @import("std");
const manifest_mod = @import("manifest.zig");
const Worker = @import("worker.zig").Worker;

fn usage() void {
    std.debug.print(
        \\Usage:
        \\  sandboxactor run <manifest.yml> <action-dir> <tmp-dir> [input-file]
        \\
    , .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 5 or !std.mem.eql(u8, args[1], "run")) {
        usage();
        return;
    }

    const manifest_bytes = try std.fs.cwd().readFileAlloc(allocator, args[2], 1024 * 1024);
    defer allocator.free(manifest_bytes);

    const manifest = try manifest_mod.parseCanonicalYaml(allocator, manifest_bytes);

    const input = if (args.len >= 6)
        try std.fs.cwd().readFileAlloc(allocator, args[5], manifest.sandbox.memory_max_bytes)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(input);

    const result = try (Worker{ .allocator = allocator }).execute(
        manifest,
        args[3],
        args[4],
        input,
    );
    defer allocator.free(result.output);

    try std.fs.File.stdout().writeAll(result.output);
}
