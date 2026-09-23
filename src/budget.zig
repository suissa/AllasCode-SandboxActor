const std = @import("std");

pub const Measurement = struct {
    input_max_bytes: u64,
    memory_peak_bytes: u64,
    serialization_peak_bytes: u64,
    output_max_bytes: u64,
    cpu_time_ns: u64,
    wall_time_ns: u64,
    zeroization_time_ns: u64,
};

pub const Offset = struct {
    /// basis points: 2000 = 20%
    basis_points: u32,

    pub fn apply(self: Offset, value: u64) !u64 {
        const extra = try std.math.mul(u64, value, self.basis_points);
        return try std.math.add(u64, value, extra / 10_000);
    }
};

pub const ResourceBudget = struct {
    memory_max_bytes: u64,
    cpu_max_ns: u64,
    wall_max_ns: u64,
    input_max_bytes: u64,
    output_max_bytes: u64,
    serialization_max_bytes: u64,
    zeroization_max_ns: u64,

    pub fn derive(measured: Measurement, memory_offset: Offset, cpu_offset: Offset, wall_offset: Offset) !ResourceBudget {
        const memory_base = try std.math.add(
            u64,
            try std.math.add(u64, measured.input_max_bytes, measured.memory_peak_bytes),
            try std.math.add(u64, measured.serialization_peak_bytes, measured.output_max_bytes),
        );

        return .{
            .memory_max_bytes = try memory_offset.apply(memory_base),
            .cpu_max_ns = try cpu_offset.apply(measured.cpu_time_ns),
            .wall_max_ns = try wall_offset.apply(measured.wall_time_ns),
            .input_max_bytes = measured.input_max_bytes,
            .output_max_bytes = measured.output_max_bytes,
            .serialization_max_bytes = measured.serialization_peak_bytes,
            .zeroization_max_ns = measured.zeroization_time_ns,
        };
    }
};

test "20 percent offset" {
    try std.testing.expectEqual(@as(u64, 120), try (Offset{ .basis_points = 2000 }).apply(100));
}
