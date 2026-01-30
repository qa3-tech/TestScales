//! TestScales Sample Tests
//! Cross-platform examples demonstrating framework features
//!
//! Build and run:
//!   zig build run
//!   zig build run -- --help
//!   zig build run -- --suite "Math"
//!   zig build run -- --xml results.xml

const std = @import("std");
const ts = @import("testscales");
const builtin = @import("builtin");

// ============================================================
// MATH TESTS - Basic assertions
// ============================================================

fn testAdditionWorks(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 4, 2 + 2, "should equal 4", @src());
}

fn testStringLength(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectLen(a, 5, "hello".len, "should be 5 chars", @src());
}

fn testPositiveNumbers(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectTrue(a, 5 > 0, "should be positive", @src());
}

const math_suite = ts.Suite(void).init("Math Tests", &.{
    ts.Test(void).init("addition works", testAdditionWorks),
    ts.Test(void).init("string length", testStringLength),
    ts.Test(void).init("positive numbers", testPositiveNumbers),
});

// ============================================================
// VALIDATION TESTS - Combining assertions (error accumulation)
// ============================================================

fn testValidateOrder(a: std.mem.Allocator, _: void) ts.TestResult {
    const total: i32 = 100;
    const item_count: i32 = 3;
    const has_customer = true;

    return ts.combineAll(a, &.{
        ts.expectTrue(a, total > 0, "total positive", @src()),
        ts.expectTrue(a, item_count > 0, "has items", @src()),
        ts.expectTrue(a, has_customer, "has customer", @src()),
    });
}

fn testDependentChecks(a: std.mem.Allocator, _: void) ts.TestResult {
    const x: i32 = 42;

    // Short-circuit: if first fails, return immediately
    const r1 = ts.expectTrue(a, x > 0, "must be positive", @src());
    if (r1.isFail()) return r1;

    const r2 = ts.expectTrue(a, x < 100, "must be under 100", @src());
    if (r2.isFail()) return r2;

    return ts.expectEqual(a, i32, 42, x, "should be 42", @src());
}

const validation_suite = ts.Suite(void).init("Validation Tests", &.{
    ts.Test(void).init("validate order (accumulate)", testValidateOrder),
    ts.Test(void).init("dependent checks (short-circuit)", testDependentChecks),
});

// ============================================================
// SKIP TESTS - Conditional execution
// ============================================================

fn testPosixOnly(a: std.mem.Allocator, _: void) ts.TestResult {
    const is_posix = builtin.os.tag != .windows;

    const skip_result = ts.skipUnless(is_posix, "POSIX only test");
    if (skip_result.isSkip()) return skip_result;

    return ts.expectTrue(a, true, "posix-specific logic", @src());
}

fn testWindowsOnly(a: std.mem.Allocator, _: void) ts.TestResult {
    const is_windows = builtin.os.tag == .windows;

    const skip_result = ts.skipUnless(is_windows, "Windows only test");
    if (skip_result.isSkip()) return skip_result;

    return ts.expectTrue(a, true, "windows-specific logic", @src());
}

fn testSkipInCi(a: std.mem.Allocator, _: void) ts.TestResult {
    const is_ci = std.posix.getenv("CI") != null;

    const skip_result = ts.skipIf(is_ci, "too slow for CI");
    if (skip_result.isSkip()) return skip_result;

    return ts.expectTrue(a, true, "slow test logic here", @src());
}

const skip_suite = ts.Suite(void).init("Skip Tests", &.{
    ts.Test(void).init("posix only", testPosixOnly),
    ts.Test(void).init("windows only", testWindowsOnly),
    ts.Test(void).init("skip in CI", testSkipInCi),
    ts.Test(void).skip("not implemented", "waiting for feature X"),
});

// ============================================================
// COLLECTION TESTS
// ============================================================

fn testCollectionContains(a: std.mem.Allocator, _: void) ts.TestResult {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };

    return ts.combineAll(a, &.{
        ts.expectNotEmpty(a, i32, &arr, "should have elements", @src()),
        ts.expectLen(a, 5, arr.len, "should have 5 elements", @src()),
        ts.expectContains(a, i32, &arr, 3, "should contain 3", @src()),
        ts.expectNotContains(a, i32, &arr, 99, "should not contain 99", @src()),
    });
}

fn testEmptyCollection(a: std.mem.Allocator, _: void) ts.TestResult {
    const arr: []const i32 = &.{};
    return ts.expectEmpty(a, i32, arr, "should be empty", @src());
}

const collection_suite = ts.Suite(void).init("Collection Tests", &.{
    ts.Test(void).init("contains and length", testCollectionContains),
    ts.Test(void).init("empty collection", testEmptyCollection),
});

// ============================================================
// NUMERIC COMPARISON TESTS
// ============================================================

fn testNumericComparisons(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.combineAll(a, &.{
        ts.expectGreater(a, i32, 10, 5, "10 > 5", @src()),
        ts.expectLess(a, i32, 3, 7, "3 < 7", @src()),
        ts.expectGreaterOrEqual(a, i32, 5, 5, "5 >= 5", @src()),
        ts.expectLessOrEqual(a, i32, 5, 5, "5 <= 5", @src()),
    });
}

fn testFloatingPoint(a: std.mem.Allocator, _: void) ts.TestResult {
    const pi: f64 = 3.14159;
    const calculated: f64 = 22.0 / 7.0;

    return ts.expectInDelta(a, f64, pi, calculated, 0.01, "close to pi", @src());
}

const numeric_suite = ts.Suite(void).init("Numeric Tests", &.{
    ts.Test(void).init("comparisons", testNumericComparisons),
    ts.Test(void).init("floating point delta", testFloatingPoint),
});

// ============================================================
// STRING TESTS
// ============================================================

fn testStringEquality(a: std.mem.Allocator, _: void) ts.TestResult {
    const expected = "hello";
    const actual = "hello";
    return ts.expectEqual(a, []const u8, expected, actual, "strings match", @src());
}

fn testStringNotEqual(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectNotEqual(a, []const u8, "hello", "world", "different strings", @src());
}

fn testStringContains(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectStringContains(a, "hello world", "world", "contains world", @src());
}

const string_suite = ts.Suite(void).init("String Tests", &.{
    ts.Test(void).init("equality", testStringEquality),
    ts.Test(void).init("not equal", testStringNotEqual),
    ts.Test(void).init("contains", testStringContains),
});

// ============================================================
// NIL/NULL TESTS
// ============================================================

fn testNilChecking(a: std.mem.Allocator, _: void) ts.TestResult {
    const valid: ?[]const u8 = "hello";
    const empty: ?[]const u8 = null;

    return ts.combineAll(a, &.{
        ts.expectNotNull(a, valid, "should not be null", @src()),
        ts.expectNull(a, empty, "should be null", @src()),
    });
}

const nil_suite = ts.Suite(void).init("Nil Tests", &.{
    ts.Test(void).init("nil checking", testNilChecking),
});

// ============================================================
// DATA-DRIVEN TESTS
// ============================================================

fn testDouble2(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 4, 2 * 2, "2 * 2 = 4", @src());
}
fn testDouble5(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 10, 5 * 2, "5 * 2 = 10", @src());
}
fn testDouble10(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 20, 10 * 2, "10 * 2 = 20", @src());
}
fn testDouble0(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 0, 0 * 2, "0 * 2 = 0", @src());
}
fn testDoubleNeg(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, -10, -5 * 2, "-5 * 2 = -10", @src());
}

const data_suite = ts.Suite(void).init("Data-Driven Tests", &.{
    ts.Test(void).init("2 * 2 = 4", testDouble2),
    ts.Test(void).init("5 * 2 = 10", testDouble5),
    ts.Test(void).init("10 * 2 = 20", testDouble10),
    ts.Test(void).init("0 * 2 = 0", testDouble0),
    ts.Test(void).init("-5 * 2 = -10", testDoubleNeg),
});

// ============================================================
// FILE TESTS - Setup/teardown with typed environment
// ============================================================

const FileEnv = struct {
    temp_dir: []const u8,
    temp_file: []const u8,
};

fn fileSetup(allocator: std.mem.Allocator) ?FileEnv {
    const timestamp = std.time.timestamp();
    const temp_dir = std.fmt.allocPrint(allocator, "/tmp/testscales_{d}", .{timestamp}) catch return null;

    std.fs.cwd().makeDir(temp_dir) catch |err| {
        if (err != error.PathAlreadyExists) return null;
    };

    const temp_file = std.fmt.allocPrint(allocator, "{s}/test.txt", .{temp_dir}) catch return null;

    std.debug.print("  [setup] Created temp dir: {s}\n", .{temp_dir});
    return .{
        .temp_dir = temp_dir,
        .temp_file = temp_file,
    };
}

fn fileTeardown(env: FileEnv) void {
    std.fs.cwd().deleteFile(env.temp_file) catch {};
    std.fs.cwd().deleteDir(env.temp_dir) catch {};
    std.debug.print("  [teardown] Cleaned up temp dir\n", .{});
}

fn testCanCreateFile(a: std.mem.Allocator, env: FileEnv) ts.TestResult {
    const file = std.fs.cwd().createFile(env.temp_file, .{}) catch {
        return ts.fail(a, "could not create file", @src());
    };
    file.writeAll("hello") catch {
        return ts.fail(a, "could not write to file", @src());
    };
    file.close();

    // Check file exists
    std.fs.cwd().access(env.temp_file, .{}) catch {
        return ts.fail(a, "file should exist", @src());
    };

    return ts.pass();
}

fn testCanReadFile(a: std.mem.Allocator, env: FileEnv) ts.TestResult {
    // Write
    const write_file = std.fs.cwd().createFile(env.temp_file, .{}) catch {
        return ts.fail(a, "could not create file", @src());
    };
    write_file.writeAll("hello") catch {
        return ts.fail(a, "could not write", @src());
    };
    write_file.close();

    // Read
    const read_file = std.fs.cwd().openFile(env.temp_file, .{}) catch {
        return ts.fail(a, "could not open file", @src());
    };
    defer read_file.close();

    var buf: [64]u8 = undefined;
    const bytes_read = read_file.readAll(&buf) catch {
        return ts.fail(a, "could not read", @src());
    };

    return ts.expectEqual(a, []const u8, "hello", buf[0..bytes_read], "should read content", @src());
}

const file_suite = ts.Suite(FileEnv).initWith(
    "File Operations",
    fileSetup,
    fileTeardown,
    &.{
        ts.Test(FileEnv).init("can create file", testCanCreateFile),
        ts.Test(FileEnv).init("can read file", testCanReadFile),
        ts.Test(FileEnv).skip("performance test", "too slow for regular runs"),
    },
);

// ============================================================
// MAIN
// ============================================================

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Collect args
    const args = std.process.argsAlloc(allocator) catch return 1;
    defer std.process.argsFree(allocator, args);

    return ts.run(allocator, &.{
        comptime ts.erased(void, &math_suite),
        comptime ts.erased(void, &validation_suite),
        comptime ts.erased(void, &skip_suite),
        comptime ts.erased(void, &collection_suite),
        comptime ts.erased(void, &numeric_suite),
        comptime ts.erased(void, &string_suite),
        comptime ts.erased(void, &nil_suite),
        comptime ts.erased(void, &data_suite),
        comptime ts.erased(FileEnv, &file_suite),
    }, args);
}
