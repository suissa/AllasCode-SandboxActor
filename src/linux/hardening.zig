const builtin = @import("builtin");

const c = @cImport({
    @cInclude("sys/prctl.h");
    @cInclude("linux/prctl.h");
});

pub fn noNewPrivileges() !void {
    if (builtin.os.tag != .linux) return error.UnsupportedPlatform;
    if (c.prctl(c.PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0)
        return error.NoNewPrivilegesFailed;
}
