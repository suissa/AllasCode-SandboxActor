const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/syscall.h");
    @cInclude("linux/landlock.h");
});

pub const Access = struct {
    read: bool = true,
    execute: bool = false,
    write: bool = false,
};

pub const Rule = struct {
    path: []const u8,
    access: Access,
};

fn mask(a: Access) u64 {
    var m: u64 = 0;
    if (a.execute) m |= c.LANDLOCK_ACCESS_FS_EXECUTE;
    if (a.read) {
        m |= c.LANDLOCK_ACCESS_FS_READ_FILE;
        m |= c.LANDLOCK_ACCESS_FS_READ_DIR;
    }
    if (a.write) {
        m |= c.LANDLOCK_ACCESS_FS_WRITE_FILE;
        m |= c.LANDLOCK_ACCESS_FS_REMOVE_DIR;
        m |= c.LANDLOCK_ACCESS_FS_REMOVE_FILE;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_CHAR;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_DIR;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_REG;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_SOCK;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_FIFO;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_BLOCK;
        m |= c.LANDLOCK_ACCESS_FS_MAKE_SYM;
    }
    return m;
}

pub fn enforce(allocator: std.mem.Allocator, rules: []const Rule) !void {
    if (builtin.os.tag != .linux) return error.UnsupportedPlatform;

    const handled: u64 =
        c.LANDLOCK_ACCESS_FS_EXECUTE |
        c.LANDLOCK_ACCESS_FS_WRITE_FILE |
        c.LANDLOCK_ACCESS_FS_READ_FILE |
        c.LANDLOCK_ACCESS_FS_READ_DIR |
        c.LANDLOCK_ACCESS_FS_REMOVE_DIR |
        c.LANDLOCK_ACCESS_FS_REMOVE_FILE |
        c.LANDLOCK_ACCESS_FS_MAKE_CHAR |
        c.LANDLOCK_ACCESS_FS_MAKE_DIR |
        c.LANDLOCK_ACCESS_FS_MAKE_REG |
        c.LANDLOCK_ACCESS_FS_MAKE_SOCK |
        c.LANDLOCK_ACCESS_FS_MAKE_FIFO |
        c.LANDLOCK_ACCESS_FS_MAKE_BLOCK |
        c.LANDLOCK_ACCESS_FS_MAKE_SYM;

    var ruleset_attr = c.struct_landlock_ruleset_attr{ .handled_access_fs = handled };
    const ruleset = c.syscall(
        c.SYS_landlock_create_ruleset,
        &ruleset_attr,
        @sizeOf(@TypeOf(ruleset_attr)),
        0,
    );
    if (ruleset < 0) return error.LandlockUnavailable;
    defer _ = c.close(@intCast(ruleset));

    for (rules) |rule| {
        const zpath = try allocator.dupeZ(u8, rule.path);
        defer allocator.free(zpath);

        const fd = c.open(zpath.ptr, c.O_PATH | c.O_CLOEXEC);
        if (fd < 0) return error.LandlockFailed;
        defer _ = c.close(fd);

        var beneath = c.struct_landlock_path_beneath_attr{
            .allowed_access = mask(rule.access),
            .parent_fd = fd,
        };

        if (c.syscall(
            c.SYS_landlock_add_rule,
            @as(c_int, @intCast(ruleset)),
            c.LANDLOCK_RULE_PATH_BENEATH,
            &beneath,
            0,
        ) < 0) return error.LandlockFailed;
    }

    if (c.syscall(c.SYS_landlock_restrict_self, @as(c_int, @intCast(ruleset)), 0) < 0)
        return error.LandlockFailed;
}
