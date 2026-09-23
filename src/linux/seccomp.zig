const builtin = @import("builtin");

const c = @cImport({
    @cInclude("stddef.h");
    @cInclude("errno.h");
    @cInclude("linux/filter.h");
    @cInclude("linux/seccomp.h");
    @cInclude("linux/audit.h");
    @cInclude("sys/prctl.h");
    @cInclude("sys/syscall.h");
});

fn stmt(code: u16, k: u32) c.struct_sock_filter {
    return .{ .code = code, .jt = 0, .jf = 0, .k = k };
}

fn jump(code: u16, k: u32, jt: u8, jf: u8) c.struct_sock_filter {
    return .{ .code = code, .jt = jt, .jf = jf, .k = k };
}

fn denyErrno(errno_value: u32) c.struct_sock_filter {
    return stmt(c.BPF_RET | c.BPF_K, c.SECCOMP_RET_ERRNO | (errno_value & c.SECCOMP_RET_DATA));
}

fn allow() c.struct_sock_filter {
    return stmt(c.BPF_RET | c.BPF_K, c.SECCOMP_RET_ALLOW);
}

/// Lightweight deny-list profile intended to complement Landlock.
/// It is intentionally small: filesystem policy belongs to Landlock.
pub fn apply(deny_network: bool, deny_spawn: bool) !void {
    if (builtin.os.tag != .linux) return error.UnsupportedPlatform;

    var filter: [32]c.struct_sock_filter = undefined;
    var n: usize = 0;

    // Load syscall number from struct seccomp_data.nr.
    filter[n] = stmt(c.BPF_LD | c.BPF_W | c.BPF_ABS, @offsetOf(c.struct_seccomp_data, "nr"));
    n += 1;

    if (deny_network) {
        const syscalls = [_]u32{
            c.SYS_socket,
            c.SYS_socketpair,
            c.SYS_connect,
            c.SYS_bind,
            c.SYS_listen,
            c.SYS_accept,
            c.SYS_accept4,
            c.SYS_sendto,
            c.SYS_recvfrom,
            c.SYS_sendmsg,
            c.SYS_recvmsg,
        };
        inline for (syscalls) |nr| {
            filter[n] = jump(c.BPF_JMP | c.BPF_JEQ | c.BPF_K, nr, 0, 1);
            n += 1;
            filter[n] = denyErrno(c.EPERM);
            n += 1;
        }
    }

    if (deny_spawn) {
        const spawn_syscalls = [_]u32{
            c.SYS_fork,
            c.SYS_vfork,
            c.SYS_clone,
            c.SYS_clone3,
            c.SYS_execve,
            c.SYS_execveat,
        };
        inline for (spawn_syscalls) |nr| {
            filter[n] = jump(c.BPF_JMP | c.BPF_JEQ | c.BPF_K, nr, 0, 1);
            n += 1;
            filter[n] = denyErrno(c.EPERM);
            n += 1;
        }
    }

    filter[n] = allow();
    n += 1;

    var prog = c.struct_sock_fprog{
        .len = @intCast(n),
        .filter = &filter,
    };

    if (c.prctl(c.PR_SET_SECCOMP, c.SECCOMP_MODE_FILTER, &prog) != 0)
        return error.SeccompFailed;
}
