const builtin = @import("builtin");

const c = @cImport({
    @cInclude("sys/resource.h");
});

pub const Limits = struct {
    memory_bytes: u64,
    cpu_seconds: u64,
    max_processes: u64 = 1,
    max_open_files: u64 = 64,
};

fn set(which: c_int, value: u64) !void {
    var lim = c.struct_rlimit{
        .rlim_cur = @intCast(value),
        .rlim_max = @intCast(value),
    };
    if (c.setrlimit(which, &lim) != 0)
        return error.ResourceLimitFailed;
}

pub fn apply(limits: Limits) !void {
    if (builtin.os.tag != .linux) return error.UnsupportedPlatform;
    try set(c.RLIMIT_AS, limits.memory_bytes);
    try set(c.RLIMIT_CPU, limits.cpu_seconds);
    try set(c.RLIMIT_NOFILE, limits.max_open_files);

    if (@hasDecl(c, "RLIMIT_NPROC"))
        try set(c.RLIMIT_NPROC, limits.max_processes);
}
