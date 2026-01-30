const std = @import("std");
const result = @import("result.zig");
const output = @import("output.zig");

pub const TestResult = result.TestResult;
pub const TestOutcome = output.TestOutcome;
pub const SuiteOutcome = output.SuiteOutcome;
pub const RunSummary = output.RunSummary;

// ============================================================
// Core Types
// ============================================================

pub fn TestFn(comptime Env: type) type {
    return *const fn (std.mem.Allocator, Env) TestResult;
}

pub fn Test(comptime Env: type) type {
    return struct {
        name: []const u8,
        func: ?TestFn(Env) = null,
        skip_reason: ?[]const u8 = null,

        const Self = @This();

        pub fn init(name: []const u8, func: TestFn(Env)) Self {
            return .{ .name = name, .func = func };
        }

        pub fn skip(name: []const u8, reason: []const u8) Self {
            return .{ .name = name, .skip_reason = reason };
        }
    };
}

pub fn SetupFn(comptime Env: type) type {
    return *const fn (std.mem.Allocator) ?Env;
}

pub fn TeardownFn(comptime Env: type) type {
    return *const fn (Env) void;
}

pub fn Suite(comptime Env: type) type {
    return struct {
        name: []const u8,
        tests: []const Test(Env),
        setup: ?SetupFn(Env) = null,
        teardown: ?TeardownFn(Env) = null,

        const Self = @This();

        pub fn init(name: []const u8, tests: []const Test(Env)) Self {
            return .{ .name = name, .tests = tests };
        }

        pub fn initWith(name: []const u8, setup: SetupFn(Env), teardown: TeardownFn(Env), tests: []const Test(Env)) Self {
            return .{ .name = name, .tests = tests, .setup = setup, .teardown = teardown };
        }
    };
}

// ============================================================
// Type-Erased Suite
// ============================================================

pub const ErasedSuite = struct {
    name: []const u8,
    test_count: usize,
    runFn: *const fn (std.mem.Allocator, ?[]const u8) SuiteOutcome,

    pub fn run(self: ErasedSuite, allocator: std.mem.Allocator, filter: ?[]const u8) SuiteOutcome {
        return self.runFn(allocator, filter);
    }
};

/// Create a type-erased suite from a comptime-known suite.
/// Usage: `erased(void, &my_suite)` or `my_suite.erased()`
pub fn erased(comptime Env: type, comptime suite: *const Suite(Env)) ErasedSuite {
    const S = struct {
        fn run(allocator: std.mem.Allocator, test_filter: ?[]const u8) SuiteOutcome {
            return runSuiteImpl(Env, suite.*, allocator, test_filter);
        }
    };
    return .{
        .name = suite.name,
        .test_count = suite.tests.len,
        .runFn = S.run,
    };
}

// ============================================================
// Runners
// ============================================================

fn runSuiteImpl(comptime Env: type, suite: Suite(Env), allocator: std.mem.Allocator, test_filter: ?[]const u8) SuiteOutcome {
    var timer = std.time.Timer.start() catch return SuiteOutcome{
        .name = suite.name,
        .tests = &[_]TestOutcome{},
        .elapsed_ns = 0,
        .setup_failed = true,
    };

    // Setup
    var env: Env = undefined;
    if (suite.setup) |setup_fn| {
        if (setup_fn(allocator)) |e| {
            env = e;
        } else {
            return SuiteOutcome{
                .name = suite.name,
                .tests = &[_]TestOutcome{},
                .elapsed_ns = timer.read(),
                .setup_failed = true,
            };
        }
    } else if (Env == void) {
        env = {};
    } else {
        return SuiteOutcome{
            .name = suite.name,
            .tests = &[_]TestOutcome{},
            .elapsed_ns = timer.read(),
            .setup_failed = true,
        };
    }

    defer if (suite.teardown) |teardown_fn| teardown_fn(env);

    // Run tests
    var outcomes = std.ArrayList(TestOutcome).init(allocator);
    for (suite.tests) |t| {
        if (test_filter) |filter| {
            if (std.mem.indexOf(u8, t.name, filter) == null) continue;
        }

        var test_timer = std.time.Timer.start() catch continue;
        const r = if (t.skip_reason) |reason|
            result.skip(reason)
        else if (t.func) |func|
            func(allocator, env)
        else
            result.skip("no test function");

        outcomes.append(.{
            .name = t.name,
            .result = r,
            .elapsed_ns = test_timer.read(),
        }) catch continue;
    }

    return SuiteOutcome{
        .name = suite.name,
        .tests = outcomes.toOwnedSlice() catch &[_]TestOutcome{},
        .elapsed_ns = timer.read(),
    };
}

pub fn runAll(allocator: std.mem.Allocator, suites: []const ErasedSuite) struct { summary: RunSummary, outcomes: []const SuiteOutcome } {
    var timer = std.time.Timer.start() catch return .{ .summary = .{}, .outcomes = &[_]SuiteOutcome{} };
    var summary = RunSummary{};
    var outcomes = std.ArrayList(SuiteOutcome).init(allocator);

    for (suites) |suite| {
        const outcome = suite.run(allocator, null);
        if (outcome.setup_failed) {
            summary.errored += suite.test_count;
        } else {
            summary.passed += outcome.passed();
            summary.failed += outcome.failed();
            summary.skipped += outcome.skipped();
        }
        outcomes.append(outcome) catch continue;
    }

    summary.elapsed_ns = timer.read();
    return .{
        .summary = summary,
        .outcomes = outcomes.toOwnedSlice() catch &[_]SuiteOutcome{},
    };
}

// ============================================================
// CLI
// ============================================================

pub const CliOptions = struct {
    help: bool = false,
    list: bool = false,
    suite_filter: ?[]const u8 = null,
    test_filter: ?[]const u8 = null,
    match_filter: ?[]const u8 = null,
    xml_file: ?[]const u8 = null,
};

pub fn parseArgs(args: []const []const u8) CliOptions {
    var opts = CliOptions{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            opts.help = true;
        } else if (std.mem.eql(u8, arg, "--list")) {
            opts.list = true;
        } else if (std.mem.eql(u8, arg, "--suite") and i + 1 < args.len) {
            i += 1;
            opts.suite_filter = args[i];
        } else if (std.mem.eql(u8, arg, "--test") and i + 2 < args.len) {
            i += 1;
            opts.suite_filter = args[i];
            i += 1;
            opts.test_filter = args[i];
        } else if (std.mem.eql(u8, arg, "--match") and i + 1 < args.len) {
            i += 1;
            opts.match_filter = args[i];
        } else if (std.mem.eql(u8, arg, "--xml") and i + 1 < args.len) {
            i += 1;
            opts.xml_file = args[i];
        }
    }
    return opts;
}

fn printHelp(prog: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        \\Usage: {s} [options]
        \\
        \\Options:
        \\  --help                  Show this help
        \\  --list                  List all tests
        \\  --suite "name"          Run specific suite
        \\  --test "suite" "test"   Run specific test
        \\  --match "pattern"       Run tests matching pattern
        \\  --xml "file"            Output results as JUnit XML
        \\
    , .{prog}) catch {};
}

fn listTests(suites: []const ErasedSuite) void {
    const stdout = std.io.getStdOut().writer();
    for (suites) |suite| {
        stdout.print("{s}: ({d} tests)\n", .{ suite.name, suite.test_count }) catch {};
    }
}

pub fn run(allocator: std.mem.Allocator, suites: []const ErasedSuite, args: []const []const u8) u8 {
    const opts = parseArgs(args);

    if (opts.help) {
        printHelp(if (args.len > 0) args[0] else "test");
        return 0;
    }

    if (opts.list) {
        listTests(suites);
        return 0;
    }

    // Filter suites
    var filtered = std.ArrayList(ErasedSuite).init(allocator);
    defer filtered.deinit();

    for (suites) |suite| {
        var include = true;
        if (opts.suite_filter) |sf| {
            include = std.mem.indexOf(u8, suite.name, sf) != null;
        }
        if (include) {
            filtered.append(suite) catch continue;
        }
    }

    if (filtered.items.len == 0) {
        std.io.getStdOut().writer().print("No tests matched filters.\n", .{}) catch {};
        return 1;
    }

    // Run
    var out = output.Output.init(true);
    const run_result = runAll(allocator, filtered.items);

    // Print results
    for (run_result.outcomes) |suite_outcome| {
        out.suiteHeader(suite_outcome.name, suite_outcome.elapsed_ns);
        if (suite_outcome.setup_failed) {
            out.suiteSetupFailed();
        } else {
            for (suite_outcome.tests) |t| {
                out.testResult(t);
            }
        }
    }

    out.summary(run_result.summary);

    // XML output
    if (opts.xml_file) |xml_path| {
        output.writeJunitXml(xml_path, run_result.outcomes, run_result.summary) catch |err| {
            std.io.getStdErr().writer().print("Error writing XML: {}\n", .{err}) catch {};
        };
        std.io.getStdOut().writer().print("\nResults written to {s}\n", .{xml_path}) catch {};
    }

    return if (run_result.summary.failed > 0 or run_result.summary.errored > 0) 1 else 0;
}
