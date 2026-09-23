const std = @import("std");

pub const TextBounds = struct {
    min_chars: usize = 0,
    max_chars: usize,
    max_bytes: usize,
    require_utf8: bool = true,

    pub fn validate(self: TextBounds, value: []const u8) !void {
        if (value.len > self.max_bytes) return error.MaxBytesExceeded;
        if (self.require_utf8 and !std.unicode.utf8ValidateSlice(value))
            return error.InvalidUtf8;

        const chars = if (self.require_utf8)
            try std.unicode.utf8CountCodepoints(value)
        else
            value.len;

        if (chars < self.min_chars) return error.MinCharsNotReached;
        if (chars > self.max_chars) return error.MaxCharsExceeded;
    }
};

pub const CollectionBounds = struct {
    max_items: usize,

    pub fn validateCount(self: CollectionBounds, count: usize) !void {
        if (count > self.max_items) return error.MaxItemsExceeded;
    }
};

pub const ObjectBounds = struct {
    max_properties: usize,
    max_depth: usize,

    pub fn validate(self: ObjectBounds, properties: usize, depth: usize) !void {
        if (properties > self.max_properties) return error.MaxPropertiesExceeded;
        if (depth > self.max_depth) return error.MaxDepthExceeded;
    }
};

pub const DecimalBounds = struct {
    max_digits: usize,
    max_scale: usize,
};

pub const BoundaryCase = enum {
    min_minus_one,
    min,
    min_plus_one,
    max_minus_one,
    max,
    max_plus_one,
    wrong_primitive,
    invalid_encoding,
    invalid_structure,
    maximum_valid_payload,
};

test "text bounds reject max plus one" {
    const bounds = TextBounds{ .max_chars = 3, .max_bytes = 3 };
    try bounds.validate("abc");
    try std.testing.expectError(error.MaxBytesExceeded, bounds.validate("abcd"));
}
