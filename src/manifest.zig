const std = @import("std");

pub const FileSystemPolicy = struct {
    self_read: bool = true,
    self_execute: bool = false,
    tmp_write: bool = false,
};

pub const ProcessPolicy = struct {
    spawn: bool = false,
};

pub const NetworkPolicy = struct {
    /// Number of requested allow-list entries found in the canonical YAML.
    /// Standalone SandboxActor currently denies all networking unless an
    /// embedding host provides a network allow-list enforcer.
    allow_count: usize = 0,
};

pub const SandboxPolicy = struct {
    enabled: bool = true,
    filesystem: FileSystemPolicy = .{},
    process: ProcessPolicy = .{},
    network: NetworkPolicy = .{},
    memory_max_bytes: u64,
    cpu_max_millicores: u32,
};

pub const Manifest = struct {
    action_name: []const u8,
    module: []const u8,
    sandbox: SandboxPolicy,
};

pub fn parseSize(text: []const u8) !u64 {
    var i: usize = 0;
    while (i < text.len and std.ascii.isDigit(text[i])) : (i += 1) {}
    if (i == 0) return error.InvalidSize;
    const n = try std.fmt.parseInt(u64, text[0..i], 10);
    const suffix = std.mem.trim(u8, text[i..], " \t");

    if (suffix.len == 0 or std.ascii.eqlIgnoreCase(suffix, "B")) return n;
    if (std.ascii.eqlIgnoreCase(suffix, "KiB")) return std.math.mul(u64, n, 1024);
    if (std.ascii.eqlIgnoreCase(suffix, "MiB")) return std.math.mul(u64, n, 1024 * 1024);
    if (std.ascii.eqlIgnoreCase(suffix, "GiB")) return std.math.mul(u64, n, 1024 * 1024 * 1024);
    return error.InvalidSize;
}

pub fn parseMillicores(text: []const u8) !u32 {
    if (text.len < 2 or text[text.len - 1] != 'm') return error.InvalidCpu;
    const value = try std.fmt.parseInt(u32, text[0 .. text.len - 1], 10);
    if (value == 0) return error.InvalidCpu;
    return value;
}

pub fn parseCanonicalYaml(allocator: std.mem.Allocator, yaml: []const u8) !Manifest {
    var action_name: ?[]const u8 = null;
    var module: ?[]const u8 = null;
    var enabled = true;
    var self_read = true;
    var self_execute = false;
    var tmp_write = false;
    var spawn = false;
    var network_allow_count: usize = 0;
    var memory: ?u64 = null;
    var cpu: ?u32 = null;

    const Section = enum {
        none, action, runtime, sandbox, filesystem_self, filesystem_tmp, process, network, network_allow, memory, cpu,
    };
    var section: Section = .none;

    var lines = std.mem.splitScalar(u8, yaml, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        if (std.mem.eql(u8, line, "action:")) { section = .action; continue; }
        if (std.mem.eql(u8, line, "runtime:")) { section = .runtime; continue; }
        if (std.mem.eql(u8, line, "sandbox:")) { section = .sandbox; continue; }
        if (std.mem.eql(u8, line, "self:")) { section = .filesystem_self; continue; }
        if (std.mem.eql(u8, line, "tmp:")) { section = .filesystem_tmp; continue; }
        if (std.mem.eql(u8, line, "process:")) { section = .process; continue; }
        if (std.mem.eql(u8, line, "network:")) { section = .network; continue; }
        if (std.mem.eql(u8, line, "allow:") and section == .network) { section = .network_allow; continue; }
        if (std.mem.eql(u8, line, "memory:")) { section = .memory; continue; }
        if (std.mem.eql(u8, line, "cpu:")) { section = .cpu; continue; }

        if (section == .network_allow and std.mem.startsWith(u8, line, "- ")) {
            network_allow_count += 1;
            continue;
        }

        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const key = std.mem.trim(u8, line[0..colon], " \t");
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t\"'");

        switch (section) {
            .action => if (std.mem.eql(u8, key, "name")) action_name = try allocator.dupe(u8, value),
            .runtime => if (std.mem.eql(u8, key, "module")) module = try allocator.dupe(u8, value),
            .sandbox => if (std.mem.eql(u8, key, "enabled")) enabled = std.mem.eql(u8, value, "true"),
            .filesystem_self => {
                if (std.mem.eql(u8, key, "read")) self_read = std.mem.eql(u8, value, "true");
                if (std.mem.eql(u8, key, "execute")) self_execute = std.mem.eql(u8, value, "true");
            },
            .filesystem_tmp => if (std.mem.eql(u8, key, "write")) tmp_write = std.mem.eql(u8, value, "true"),
            .process => if (std.mem.eql(u8, key, "spawn")) spawn = std.mem.eql(u8, value, "true"),
            .memory => if (std.mem.eql(u8, key, "max")) memory = try parseSize(value),
            .cpu => if (std.mem.eql(u8, key, "max")) cpu = try parseMillicores(value),
            else => {},
        }
    }

    return .{
        .action_name = action_name orelse return error.InvalidManifest,
        .module = module orelse return error.InvalidManifest,
        .sandbox = .{
            .enabled = enabled,
            .filesystem = .{
                .self_read = self_read,
                .self_execute = self_execute,
                .tmp_write = tmp_write,
            },
            .process = .{ .spawn = spawn },
            .network = .{ .allow_count = network_allow_count },
            .memory_max_bytes = memory orelse return error.InvalidManifest,
            .cpu_max_millicores = cpu orelse return error.InvalidManifest,
        },
    };
}

test "resource scalar parsers" {
    try std.testing.expectEqual(@as(u64, 64 * 1024 * 1024), try parseSize("64MiB"));
    try std.testing.expectEqual(@as(u32, 100), try parseMillicores("100m"));
}

test "network allow-list is detected" {
    const yaml =
        \\action:
        \\  name: X
        \\runtime:
        \\  module: ./x.so
        \\sandbox:
        \\  network:
        \\    allow:
        \\      - api.example.com
        \\  memory:
        \\    max: 1MiB
        \\  cpu:
        \\    max: 10m
    ;
    const m = try parseCanonicalYaml(std.testing.allocator, yaml);
    defer std.testing.allocator.free(m.action_name);
    defer std.testing.allocator.free(m.module);
    try std.testing.expectEqual(@as(usize, 1), m.sandbox.network.allow_count);
}
