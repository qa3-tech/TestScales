const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SourceLocation = std.builtin.SourceLocation;

pub const Failure = struct {
    message: []const u8,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
    location: SourceLocation,
};

pub const TestResult = union(enum) {
    pass,
    fail: []const Failure,
    skip: []const u8,

    pub fn isPass(self: TestResult) bool {
        return self == .pass;
    }

    pub fn isFail(self: TestResult) bool {
        return switch (self) {
            .fail => true,
            else => false,
        };
    }

    pub fn isSkip(self: TestResult) bool {
        return switch (self) {
            .skip => true,
            else => false,
        };
    }

    pub fn failures(self: TestResult) []const Failure {
        return switch (self) {
            .fail => |f| f,
            else => &[_]Failure{},
        };
    }

    pub fn skipReason(self: TestResult) ?[]const u8 {
        return switch (self) {
            .skip => |r| r,
            else => null,
        };
    }
};

pub fn pass() TestResult {
    return .pass;
}

pub fn fail(allocator: Allocator, msg: []const u8, loc: SourceLocation) TestResult {
    const fs = allocator.alloc(Failure, 1) catch return .pass;
    fs[0] = .{ .message = msg, .location = loc };
    return .{ .fail = fs };
}

pub fn failWith(
    allocator: Allocator,
    msg: []const u8,
    expected: []const u8,
    actual: []const u8,
    loc: SourceLocation,
) TestResult {
    const fs = allocator.alloc(Failure, 1) catch return .pass;
    fs[0] = .{ .message = msg, .expected = expected, .actual = actual, .location = loc };
    return .{ .fail = fs };
}

pub fn skip(reason: []const u8) TestResult {
    return .{ .skip = reason };
}

pub fn combine(allocator: Allocator, a: TestResult, b: TestResult) TestResult {
    if (a.isSkip()) return a;
    if (b.isSkip()) return b;
    if (a.isPass() and b.isPass()) return .pass;

    const a_f = a.failures();
    const b_f = b.failures();
    const combined = allocator.alloc(Failure, a_f.len + b_f.len) catch {
        if (a.isFail()) return a;
        return b;
    };
    @memcpy(combined[0..a_f.len], a_f);
    @memcpy(combined[a_f.len..], b_f);
    return .{ .fail = combined };
}

pub fn combineAll(allocator: Allocator, results: []const TestResult) TestResult {
    var result: TestResult = .pass;
    for (results) |r| {
        result = combine(allocator, result, r);
    }
    return result;
}

pub fn skipIf(cond: bool, reason: []const u8) TestResult {
    return if (cond) skip(reason) else pass();
}

pub fn skipUnless(cond: bool, reason: []const u8) TestResult {
    return if (cond) pass() else skip(reason);
}
