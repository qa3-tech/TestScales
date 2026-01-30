# TestScales

Minimal Zig testing framework using Railway-Oriented Programming.

## When to Use TestScales

TestScales is **not** a replacement for Zig's built-in `test` — it's complementary:

| Use Zig Built-in (`zig test`) | Use TestScales                            |
| ----------------------------- | ----------------------------------------- |
| Unit tests                    | Integration/E2E tests                     |
| Quick iteration               | CI pipelines needing JUnit XML            |
| Comptime testing              | Tests requiring setup/teardown lifecycles |
| Zero dependencies             | CLI filtering by suite/test/pattern       |
|                               | Error accumulation (see all failures)     |

## Philosophy

- **Pure Functions**: Tests are functions that return results, not side effects
- **Explicit Error Flow**: Errors are values, not exceptions or panics
- **Composability**: Tests compose using `combine` — accumulate or short-circuit
- **No Magic**: Setup/teardown is explicit data flow, not hidden framework behavior
- **Type Safety**: Test environments are strongly typed via comptime generics

## Features

- **Zero dependencies** — pure Zig, no external packages
- **Zig package manager** — add via `build.zig.zon`
- **Structured errors** — expected/actual values with source locations
- **Error accumulation** — `combine`/`combineAll` to see all failures
- **Typed environments** — setup/teardown with comptime generics
- **Skip directives** — `skipIf`, `skipUnless`, `Test.skip`
- **JUnit XML output** — CI integration (`--xml results.xml`)
- **CLI filtering** — `--suite`, `--test`, `--match`
- **Colored output** — auto-detected TTY, `--no-color` to disable
- **Cross-platform** — Linux, macOS, Windows

## Requirements

- Zig 0.13.x

## Installation

### Option 1: Zig Package Manager (recommended)

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .testscales = .{
        .url = "https://github.com/qa3-tech/testscales/archive/refs/tags/0.1.0.tar.gz",
        .hash = "...", // zig build will tell you the correct hash
    },
},
```

Then in your `build.zig`:

```zig
const testscales = b.dependency("testscales", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("testscales", testscales.module("testscales"));
```

### Option 2: Git Submodule

```bash
git submodule add https://github.com/qa3-tech/testscales.git deps/testscales
```

Then in `build.zig`:

```zig
const testscales_mod = b.addModule("testscales", .{
    .root_source_file = b.path("deps/testscales/src/testscales.zig"),
});
exe.root_module.addImport("testscales", testscales_mod);
```

### Option 3: Direct Download

Download a release from [GitHub Releases](https://github.com/qa3-tech/testscales/releases) and extract to your project.

## Quick Start

```zig
const std = @import("std");
const ts = @import("testscales");

fn testAddition(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.expectEqual(a, i32, 4, 2 + 2, "should add", @src());
}

fn testValidation(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.combineAll(a, &.{
        ts.expectTrue(a, 5 > 0, "positive", @src()),
        ts.expectTrue(a, 5 < 10, "under 10", @src()),
    });
}

const math_suite = ts.Suite(void).init("Math", &.{
    ts.Test(void).init("addition", testAddition),
    ts.Test(void).init("validation", testValidation),
});

pub fn main() u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = std.process.argsAlloc(allocator) catch return 1;
    defer std.process.argsFree(allocator, args);

    return ts.run(allocator, .{ &math_suite }, args);
}
```

### Build and Run

```bash
zig build test

# CLI options
zig build test -- --help
zig build test -- --suite "Math"
zig build test -- --match "valid"
zig build test -- --xml results.xml
zig build test -- --list
```

## Core Concepts

### 1. Test Results (The Railway)

Tests return one of three results:

```zig
pub const TestResult = union(enum) {
    pass,
    fail: []const Failure,  // accumulated errors
    skip: []const u8,       // skip reason
};

pub const Failure = struct {
    message: []const u8,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
    location: std.builtin.SourceLocation,
};
```

### 2. Test Functions

```zig
// Test function signature: (allocator, environment) -> TestResult
fn myTest(a: std.mem.Allocator, env: MyEnv) ts.TestResult {
    // a is arena-scoped to the suite
    // env is your typed environment (void if no setup)
    return ts.pass();
}
```

### 3. Assertions

All assertions return `TestResult` and take source location for error reporting:

```zig
// Boolean
ts.expectTrue(a, condition, "message", @src())
ts.expectFalse(a, condition, "message", @src())

// Equality (generic)
ts.expectEqual(a, i32, expected, actual, "message", @src())
ts.expectNotEqual(a, []const u8, unexpected, actual, "message", @src())

// Null/Optional
ts.expectNull(a, value, "message", @src())
ts.expectNotNull(a, value, "message", @src())

// Numeric comparisons
ts.expectGreater(a, i32, actual, than, "message", @src())
ts.expectGreaterOrEqual(a, f64, actual, than, "message", @src())
ts.expectLess(a, i32, actual, than, "message", @src())
ts.expectLessOrEqual(a, i32, actual, than, "message", @src())
ts.expectInDelta(a, f64, expected, actual, delta, "message", @src())

// Collections
ts.expectEmpty(a, i32, slice, "message", @src())
ts.expectNotEmpty(a, i32, slice, "message", @src())
ts.expectLen(a, expected_len, actual_len, "message", @src())
ts.expectContains(a, i32, slice, elem, "message", @src())
ts.expectNotContains(a, i32, slice, elem, "message", @src())

// Strings
ts.expectStringContains(a, haystack, needle, "message", @src())
ts.expectStringStartsWith(a, str, prefix, "message", @src())
ts.expectStringEndsWith(a, str, suffix, "message", @src())
```

### 4. Composition

**Accumulate all errors** (all assertions run):

```zig
fn testValidateOrder(a: std.mem.Allocator, _: void) ts.TestResult {
    return ts.combineAll(a, &.{
        ts.expectTrue(a, order.total > 0, "total positive", @src()),
        ts.expectTrue(a, order.items.len > 0, "has items", @src()),
        ts.expectNotNull(a, order.customer_id, "has customer", @src()),
    });
}
// If all fail, you see ALL three errors
```

**Short-circuit on first failure** (stops at first error):

```zig
fn testDependentChecks(a: std.mem.Allocator, _: void) ts.TestResult {
    const r = ts.expectNotNull(a, user, "user exists", @src());
    if (r.isFail()) return r;

    // Only runs if user exists
    return ts.expectEqual(a, []const u8, "alice", user.?.name, "name matches", @src());
}
```

### 5. Skip Directives

```zig
// Skip entire test
ts.Test(void).skip("not implemented", "waiting for feature X")

// Conditional skip
fn testLinuxOnly(a: std.mem.Allocator, _: void) ts.TestResult {
    const skip_result = ts.skipUnless(builtin.os.tag == .linux, "Linux only");
    if (skip_result.isSkip()) return skip_result;

    return ts.expectTrue(a, true, "linux test logic", @src());
}

fn testSkipInCi(a: std.mem.Allocator, _: void) ts.TestResult {
    const is_ci = std.posix.getenv("CI") != null;
    const skip_result = ts.skipIf(is_ci, "too slow for CI");
    if (skip_result.isSkip()) return skip_result;

    return ts.expectTrue(a, true, "slow test logic", @src());
}
```

## Setup and Teardown

Create a typed environment for tests in a suite:

```zig
const FileEnv = struct {
    temp_dir: []const u8,
    temp_file: []const u8,
};

fn fileSetup(allocator: std.mem.Allocator) ?FileEnv {
    // Return null to abort suite
    const temp_dir = std.fmt.allocPrint(allocator, "/tmp/tests", .{}) catch return null;
    std.fs.cwd().makeDir(temp_dir) catch {};
    const temp_file = std.fmt.allocPrint(allocator, "{s}/test.txt", .{temp_dir}) catch return null;
    return .{ .temp_dir = temp_dir, .temp_file = temp_file };
}

fn fileTeardown(env: FileEnv) void {
    std.fs.cwd().deleteFile(env.temp_file) catch {};
    std.fs.cwd().deleteDir(env.temp_dir) catch {};
}

fn testCanCreateFile(a: std.mem.Allocator, env: FileEnv) ts.TestResult {
    // Use env.temp_file, etc.
    return ts.pass();
}

const file_suite = ts.Suite(FileEnv).initWith(
    "File Operations",
    fileSetup,
    fileTeardown,
    &.{
        ts.Test(FileEnv).init("can create file", testCanCreateFile),
        ts.Test(FileEnv).skip("perf test", "too slow"),
    },
);
```

## CLI Options

```
Usage: ./tests [options]

Options:
  --help                  Show help
  --list                  List all tests
  --suite "name"          Run specific suite
  --test "suite" "test"   Run specific test
  --match "pattern"       Run tests matching pattern
  --xml "file"            Output results as JUnit XML
  --no-color              Disable colored output
```

## Output Example

```
=== Math Tests (0.05ms) ===
  ✓ addition (0.01ms)
  ✓ validation (0.02ms)

=== Skip Tests (0.03ms) ===
  ○ linux only (0.00ms)
      [Linux only]
  ✓ other test (0.01ms)

=== Failing Tests (0.02ms) ===
  ✗ bad math (0.01ms)
      should equal 4
        Expected: 4
        Actual:   5
        at src/tests.zig:42

5/6 passed, 1 failed, 1 skipped, 0 errored (Total: 0.15ms)
```

## API Reference

### Result Constructors

```zig
ts.pass() -> TestResult
ts.fail(allocator, message, @src()) -> TestResult
ts.failWith(allocator, message, expected, actual, @src()) -> TestResult
ts.skip(reason) -> TestResult
```

### Result Predicates

```zig
result.isPass() -> bool
result.isFail() -> bool
result.isSkip() -> bool
```

### Composition

```zig
ts.combine(allocator, a, b) -> TestResult       // combine two results
ts.combineAll(allocator, &.{a, b, c}) -> TestResult  // combine many
```

### Skip Guards

```zig
ts.skipIf(condition, reason) -> TestResult
ts.skipUnless(condition, reason) -> TestResult
```

### Suite Construction

```zig
ts.Suite(Env).init(name, tests)
ts.Suite(Env).initWith(name, setup, teardown, tests)
ts.Test(Env).init(name, func)
ts.Test(Env).skip(name, reason)
```

### Runner

```zig
// Pass a tuple of suite pointers - different Env types are handled automatically
ts.run(allocator, .{ &math_suite, &file_suite }, args) -> u8
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-thing`)
3. Ensure tests pass (`zig build test`)
4. Submit a Pull Request

For bugs or feature requests, open an issue at [github.com/qa3-tech/testscales/issues](https://github.com/qa3-tech/testscales/issues).
