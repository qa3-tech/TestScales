//! TestScales
//! Minimal Zig testing framework using Railway-Oriented Programming.
//!
//! Tests are pure functions returning `TestResult` (pass/fail/skip).
//! Errors accumulate with `combine`. No exceptions, no magic.

const std = @import("std");

// ============================================================
// Re-exports
// ============================================================

pub const result = @import("result.zig");
pub const assert = @import("assert.zig");
pub const runner = @import("runner.zig");
pub const output = @import("output.zig");

// ============================================================
// Result Types
// ============================================================

pub const TestResult = result.TestResult;
pub const Failure = result.Failure;
pub const SourceLocation = result.SourceLocation;

// ============================================================
// Result Constructors
// ============================================================

pub const pass = result.pass;
pub const fail = result.fail;
pub const failWith = result.failWith;
pub const skip = result.skip;

// ============================================================
// Composition
// ============================================================

pub const combine = result.combine;
pub const combineAll = result.combineAll;

// ============================================================
// Skip Guards
// ============================================================

pub const skipIf = result.skipIf;
pub const skipUnless = result.skipUnless;

// ============================================================
// Assertions
// ============================================================

pub const expectTrue = assert.expectTrue;
pub const expectFalse = assert.expectFalse;
pub const expectEqual = assert.expectEqual;
pub const expectNotEqual = assert.expectNotEqual;
pub const expectNull = assert.expectNull;
pub const expectNotNull = assert.expectNotNull;
pub const expectGreater = assert.expectGreater;
pub const expectGreaterOrEqual = assert.expectGreaterOrEqual;
pub const expectLess = assert.expectLess;
pub const expectLessOrEqual = assert.expectLessOrEqual;
pub const expectInDelta = assert.expectInDelta;
pub const expectEmpty = assert.expectEmpty;
pub const expectNotEmpty = assert.expectNotEmpty;
pub const expectLen = assert.expectLen;
pub const expectContains = assert.expectContains;
pub const expectNotContains = assert.expectNotContains;
pub const expectStringContains = assert.expectStringContains;
pub const expectStringStartsWith = assert.expectStringStartsWith;
pub const expectStringEndsWith = assert.expectStringEndsWith;

// ============================================================
// Runner Types
// ============================================================

pub const Test = runner.Test;
pub const Suite = runner.Suite;
pub const TestFn = runner.TestFn;
pub const SetupFn = runner.SetupFn;
pub const TeardownFn = runner.TeardownFn;
pub const ErasedSuite = runner.ErasedSuite;
pub const TestOutcome = runner.TestOutcome;
pub const SuiteOutcome = runner.SuiteOutcome;
pub const RunSummary = runner.RunSummary;

// ============================================================
// Runner Functions
// ============================================================

pub const erased = runner.erased;
pub const runAll = runner.runAll;
pub const run = runner.run;

// ============================================================
// CLI
// ============================================================

pub const CliOptions = runner.CliOptions;
pub const parseArgs = runner.parseArgs;

// ============================================================
// Output
// ============================================================

pub const Output = output.Output;
pub const writeJunitXml = output.writeJunitXml;
