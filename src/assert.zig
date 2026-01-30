//! TestScales Assertions
//! Pure functions returning TestResult

const std = @import("std");
const result = @import("result.zig");

const TestResult = result.TestResult;
const pass = result.pass;
const failWith = result.failWith;

// ============================================================
// Boolean Assertions
// ============================================================

pub fn expectTrue(
    allocator: std.mem.Allocator,
    condition: bool,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (condition) return pass();
    return failWith(allocator, message, "true", "false", src);
}

pub fn expectFalse(
    allocator: std.mem.Allocator,
    condition: bool,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (!condition) return pass();
    return failWith(allocator, message, "false", "true", src);
}

// ============================================================
// Equality Assertions (Generic)
// ============================================================

pub fn expectEqual(
    allocator: std.mem.Allocator,
    comptime T: type,
    expected: T,
    actual: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (isEqual(T, expected, actual)) return pass();

    const exp_str = formatValue(allocator, T, expected) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectNotEqual(
    allocator: std.mem.Allocator,
    comptime T: type,
    unexpected: T,
    actual: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (!isEqual(T, unexpected, actual)) return pass();

    const unexp_str = formatValue(allocator, T, unexpected) catch "<format error>";
    const exp_str = std.fmt.allocPrint(allocator, "not {s}", .{unexp_str}) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

fn isEqual(comptime T: type, a: T, b: T) bool {
    const info = @typeInfo(T);
    return switch (info) {
        .Pointer => |ptr| if (ptr.size == .Slice and ptr.child == u8)
            std.mem.eql(u8, a, b)
        else
            a == b,
        .Optional => if (a) |av| (if (b) |bv| isEqual(@TypeOf(av), av, bv) else false) else b == null,
        else => a == b,
    };
}

fn formatValue(allocator: std.mem.Allocator, comptime T: type, value: T) ![]const u8 {
    const info = @typeInfo(T);
    return switch (info) {
        .Pointer => |ptr| if (ptr.size == .Slice and ptr.child == u8)
            try std.fmt.allocPrint(allocator, "\"{s}\"", .{value})
        else
            try std.fmt.allocPrint(allocator, "{*}", .{value}),
        .Optional => if (value) |v|
            try formatValue(allocator, @TypeOf(v), v)
        else
            try allocator.dupe(u8, "null"),
        .Float => try std.fmt.allocPrint(allocator, "{d}", .{value}),
        else => try std.fmt.allocPrint(allocator, "{any}", .{value}),
    };
}

// ============================================================
// Nil/Null Assertions
// ============================================================

pub fn expectNull(
    allocator: std.mem.Allocator,
    value: anytype,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    const is_null = switch (info) {
        .Optional => value == null,
        .Pointer => @intFromPtr(value) == 0,
        else => @compileError("expectNull requires optional or pointer type"),
    };

    if (is_null) return pass();

    const act_str = formatValue(allocator, T, value) catch "<format error>";
    return failWith(allocator, message, "null", act_str, src);
}

pub fn expectNotNull(
    allocator: std.mem.Allocator,
    value: anytype,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    const is_null = switch (info) {
        .Optional => value == null,
        .Pointer => @intFromPtr(value) == 0,
        else => @compileError("expectNotNull requires optional or pointer type"),
    };

    if (!is_null) return pass();
    return failWith(allocator, message, "non-null", "null", src);
}

// ============================================================
// Numeric Comparison Assertions
// ============================================================

pub fn expectGreater(
    allocator: std.mem.Allocator,
    comptime T: type,
    actual: T,
    than: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (actual > than) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "> {any}", .{than}) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectGreaterOrEqual(
    allocator: std.mem.Allocator,
    comptime T: type,
    actual: T,
    than: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (actual >= than) return pass();

    const exp_str = std.fmt.allocPrint(allocator, ">= {any}", .{than}) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectLess(
    allocator: std.mem.Allocator,
    comptime T: type,
    actual: T,
    than: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (actual < than) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "< {any}", .{than}) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectLessOrEqual(
    allocator: std.mem.Allocator,
    comptime T: type,
    actual: T,
    than: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (actual <= than) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "<= {any}", .{than}) catch "<format error>";
    const act_str = formatValue(allocator, T, actual) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectInDelta(
    allocator: std.mem.Allocator,
    comptime T: type,
    expected: T,
    actual: T,
    delta: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    const diff = @abs(expected - actual);
    if (diff <= delta) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "{d} +/- {d}", .{ expected, delta }) catch "<format error>";
    const act_str = std.fmt.allocPrint(allocator, "{d} (diff: {d})", .{ actual, diff }) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

// ============================================================
// Collection Assertions
// ============================================================

pub fn expectEmpty(
    allocator: std.mem.Allocator,
    comptime T: type,
    slice: []const T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (slice.len == 0) return pass();

    const act_str = std.fmt.allocPrint(allocator, "{d} elements", .{slice.len}) catch "<format error>";
    return failWith(allocator, message, "empty", act_str, src);
}

pub fn expectNotEmpty(
    allocator: std.mem.Allocator,
    comptime T: type,
    slice: []const T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (slice.len > 0) return pass();
    return failWith(allocator, message, "non-empty", "0 elements", src);
}

pub fn expectLen(
    allocator: std.mem.Allocator,
    expected: usize,
    actual: usize,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (expected == actual) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "length {d}", .{expected}) catch "<format error>";
    const act_str = std.fmt.allocPrint(allocator, "length {d}", .{actual}) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectContains(
    allocator: std.mem.Allocator,
    comptime T: type,
    slice: []const T,
    elem: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    for (slice) |item| {
        if (isEqual(T, item, elem)) return pass();
    }

    const elem_str = formatValue(allocator, T, elem) catch "<format error>";
    const exp_str = std.fmt.allocPrint(allocator, "contains {s}", .{elem_str}) catch "<format error>";
    return failWith(allocator, message, exp_str, "not found", src);
}

pub fn expectNotContains(
    allocator: std.mem.Allocator,
    comptime T: type,
    slice: []const T,
    elem: T,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    for (slice, 0..) |item, i| {
        if (isEqual(T, item, elem)) {
            const elem_str = formatValue(allocator, T, elem) catch "<format error>";
            const exp_str = std.fmt.allocPrint(allocator, "not contains {s}", .{elem_str}) catch "<format error>";
            const act_str = std.fmt.allocPrint(allocator, "found at index {d}", .{i}) catch "<format error>";
            return failWith(allocator, message, exp_str, act_str, src);
        }
    }
    return pass();
}

// ============================================================
// String Assertions
// ============================================================

pub fn expectStringContains(
    allocator: std.mem.Allocator,
    haystack: []const u8,
    needle: []const u8,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (std.mem.indexOf(u8, haystack, needle) != null) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "contains \"{s}\"", .{needle}) catch "<format error>";
    const act_str = std.fmt.allocPrint(allocator, "\"{s}\"", .{haystack}) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectStringStartsWith(
    allocator: std.mem.Allocator,
    str: []const u8,
    prefix: []const u8,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (std.mem.startsWith(u8, str, prefix)) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "starts with \"{s}\"", .{prefix}) catch "<format error>";
    const act_str = std.fmt.allocPrint(allocator, "\"{s}\"", .{str}) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}

pub fn expectStringEndsWith(
    allocator: std.mem.Allocator,
    str: []const u8,
    suffix: []const u8,
    message: []const u8,
    src: std.builtin.SourceLocation,
) TestResult {
    if (std.mem.endsWith(u8, str, suffix)) return pass();

    const exp_str = std.fmt.allocPrint(allocator, "ends with \"{s}\"", .{suffix}) catch "<format error>";
    const act_str = std.fmt.allocPrint(allocator, "\"{s}\"", .{str}) catch "<format error>";
    return failWith(allocator, message, exp_str, act_str, src);
}
