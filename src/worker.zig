const std = @import("std");
const Manifest = @import("manifest.zig").Manifest;
const hardening = @import("linux/hardening.zig");
const resources = @import("linux/resources.zig");
const landlock = @import("linux/landlock.zig");

pub const ExecutionResult = struct {
    output: []u8,
};

pub const Worker = struct {
    allocator: std.mem.Allocator,

    pub fn execute(
        self: Worker,
        manifest: Manifest,
        action_dir: []const u8,
        tmp_dir: []const u8,
        input: []const u8,
    ) !ExecutionResult {
        if (!manifest.sandbox.enabled) return error.PolicyDenied;

        try hardening.noNewPrivileges();

        const cpu_seconds = @max(
            @as(u64, 1),
            (@as(u64, manifest.sandbox.cpu_max_millicores) + 999) / 1000,
        );
        try resources.apply(.{
            .memory_bytes = manifest.sandbox.memory_max_bytes,
            .cpu_seconds = cpu_seconds,
            .max_processes = if (manifest.sandbox.process.spawn) 32 else 1,
        });

        var rules = std.ArrayList(landlock.Rule).empty;
        defer rules.deinit(self.allocator);

        try rules.append(self.allocator, .{
            .path = action_dir,
            .access = .{
                .read = manifest.sandbox.filesystem.self_read,
                .execute = manifest.sandbox.filesystem.self_execute,
                .write = false,
            },
        });

        if (manifest.sandbox.filesystem.tmp_write) {
            try rules.append(self.allocator, .{
                .path = tmp_dir,
                .access = .{ .read = true, .write = true, .execute = false },
            });
        }

        try landlock.enforce(self.allocator, rules.items);

        const module_path = try std.fs.path.join(self.allocator, &.{ action_dir, manifest.module });
        defer self.allocator.free(module_path);

        var lib = std.DynLib.open(module_path) catch return error.DynamicModuleOpenFailed;
        defer lib.close();

        const ExecuteFn = *const fn (
            [*]const u8,
            usize,
            *?[*]u8,
            *usize,
        ) callconv(.c) c_int;
        const FreeFn = *const fn ([*]u8, usize) callconv(.c) void;

        const execute_fn = lib.lookup(ExecuteFn, "allascode_action_execute") orelse
            return error.MissingEntrypoint;
        const free_fn = lib.lookup(FreeFn, "allascode_action_free") orelse
            return error.MissingEntrypoint;

        var out_ptr: ?[*]u8 = null;
        var out_len: usize = 0;
        const rc = execute_fn(input.ptr, input.len, &out_ptr, &out_len);
        if (rc != 0) return error.ActionFailed;

        if (out_len == 0)
            return .{ .output = try self.allocator.alloc(u8, 0) };

        const ptr = out_ptr orelse return error.ActionFailed;
        defer free_fn(ptr, out_len);

        return .{ .output = try self.allocator.dupe(u8, ptr[0..out_len]) };
    }
};
