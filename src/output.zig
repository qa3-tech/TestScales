const std = @import("std");
const result = @import("result.zig");
const Failure = result.Failure;
const TestResult = result.TestResult;

pub const Color = struct {
    pub const green = "\x1b[32m";
    pub const red = "\x1b[31m";
    pub const yellow = "\x1b[33m";
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
};

pub const TestOutcome = struct {
    name: []const u8,
    result: TestResult,
    elapsed_ns: u64,

    pub fn elapsedMs(self: TestOutcome) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) / 1_000_000.0;
    }
};

pub const SuiteOutcome = struct {
    name: []const u8,
    tests: []const TestOutcome,
    elapsed_ns: u64,
    setup_failed: bool = false,

    pub fn elapsedMs(self: SuiteOutcome) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) / 1_000_000.0;
    }

    pub fn passed(self: SuiteOutcome) usize {
        var c: usize = 0;
        for (self.tests) |t| if (t.result.isPass()) {
            c += 1;
        };
        return c;
    }

    pub fn failed(self: SuiteOutcome) usize {
        var c: usize = 0;
        for (self.tests) |t| if (t.result.isFail()) {
            c += 1;
        };
        return c;
    }

    pub fn skipped(self: SuiteOutcome) usize {
        var c: usize = 0;
        for (self.tests) |t| if (t.result.isSkip()) {
            c += 1;
        };
        return c;
    }
};

pub const RunSummary = struct {
    passed: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
    errored: usize = 0,
    elapsed_ns: u64 = 0,

    pub fn elapsedMs(self: RunSummary) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) / 1_000_000.0;
    }

    pub fn total(self: RunSummary) usize {
        return self.passed + self.failed + self.skipped + self.errored;
    }
};

pub const Output = struct {
    writer: std.fs.File.Writer,
    use_color: bool,

    pub fn init(use_color: bool) Output {
        return .{
            .writer = std.io.getStdOut().writer(),
            .use_color = use_color and std.io.getStdOut().isTty(),
        };
    }

    fn c(self: Output, col: []const u8) []const u8 {
        return if (self.use_color) col else "";
    }

    pub fn suiteHeader(self: *Output, name: []const u8, elapsed_ns: u64) void {
        const ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
        self.writer.print("\n{s}=== {s} ({d:.2}ms) ==={s}\n", .{
            self.c(Color.bold), name, ms, self.c(Color.reset),
        }) catch {};
    }

    pub fn suiteSetupFailed(self: *Output) void {
        self.writer.print("  {s}✗{s} Setup failed\n", .{
            self.c(Color.red), self.c(Color.reset),
        }) catch {};
    }

    pub fn testResult(self: *Output, outcome: TestOutcome) void {
        const ms = outcome.elapsedMs();

        switch (outcome.result) {
            .pass => {
                self.writer.print("  {s}✓{s} {s} ({d:.2}ms)\n", .{
                    self.c(Color.green), self.c(Color.reset), outcome.name, ms,
                }) catch {};
            },
            .fail => |failures| {
                self.writer.print("  {s}✗{s} {s} ({d:.2}ms)\n", .{
                    self.c(Color.red), self.c(Color.reset), outcome.name, ms,
                }) catch {};
                for (failures) |f| {
                    self.writer.print("      {s}\n", .{f.message}) catch {};
                    if (f.expected) |exp| {
                        self.writer.print("        Expected: {s}\n", .{exp}) catch {};
                    }
                    if (f.actual) |act| {
                        self.writer.print("        Actual:   {s}\n", .{act}) catch {};
                    }
                }
            },
            .skip => |reason| {
                self.writer.print("  {s}○{s} {s} ({d:.2}ms)\n", .{
                    self.c(Color.yellow), self.c(Color.reset), outcome.name, ms,
                }) catch {};
                self.writer.print("      [{s}]\n", .{reason}) catch {};
            },
        }
    }

    pub fn summary(self: *Output, s: RunSummary) void {
        self.writer.print("\n{d}/{d} passed, {d} failed, {d} skipped, {d} errored (Total: {d:.2}ms)\n", .{
            s.passed, s.total(), s.failed, s.skipped, s.errored, s.elapsedMs(),
        }) catch {};
    }
};

pub fn writeJunitXml(path: []const u8, outcomes: []const SuiteOutcome, s: RunSummary) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const w = file.writer();

    try w.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    try w.print("<testsuites tests=\"{d}\" failures=\"{d}\" errors=\"{d}\" skipped=\"{d}\" time=\"{d:.3}\">\n", .{
        s.total(), s.failed, s.errored, s.skipped, s.elapsedMs() / 1000.0,
    });

    for (outcomes) |suite| {
        try w.print("    <testsuite name=\"{s}\" tests=\"{d}\" failures=\"{d}\" errors=\"0\" skipped=\"{d}\" time=\"{d:.3}\">\n", .{
            suite.name, suite.tests.len, suite.failed(), suite.skipped(), suite.elapsedMs() / 1000.0,
        });

        for (suite.tests) |t| {
            const time_sec = t.elapsedMs() / 1000.0;
            switch (t.result) {
                .pass => try w.print("        <testcase name=\"{s}\" time=\"{d:.3}\"/>\n", .{ t.name, time_sec }),
                .fail => |failures| {
                    try w.print("        <testcase name=\"{s}\" time=\"{d:.3}\">\n", .{ t.name, time_sec });
                    if (failures.len > 0) {
                        try w.print("            <failure message=\"{s}\" type=\"AssertionError\">", .{failures[0].message});
                        for (failures) |f| {
                            try w.print("{s}\n", .{f.message});
                            if (f.expected) |exp| try w.print("  Expected: {s}\n", .{exp});
                            if (f.actual) |act| try w.print("  Actual:   {s}\n", .{act});
                        }
                        try w.writeAll("</failure>\n");
                    }
                    try w.writeAll("        </testcase>\n");
                },
                .skip => |reason| {
                    try w.print("        <testcase name=\"{s}\" time=\"0\">\n", .{t.name});
                    try w.print("            <skipped message=\"{s}\"/>\n", .{reason});
                    try w.writeAll("        </testcase>\n");
                },
            }
        }
        try w.writeAll("    </testsuite>\n");
    }
    try w.writeAll("</testsuites>\n");
}
