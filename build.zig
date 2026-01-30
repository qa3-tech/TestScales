const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module (for consumers to import)
    const testscales_mod = b.addModule("testscales", .{
        .root_source_file = b.path("src/testscales.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Static library artifact
    const lib = b.addStaticLibrary(.{
        .name = "testscales",
        .root_source_file = b.path("src/testscales.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Default: just build the library
    b.installArtifact(lib);

    // Test executable (sample_tests.zig)
    const test_exe = b.addExecutable(.{
        .name = "testscales-tests",
        .root_source_file = b.path("examples/sample_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("testscales", testscales_mod);

    // Run tests
    const run_tests = b.addRunArtifact(test_exe);
    run_tests.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_tests.addArgs(args);
    }

    // `zig build test` - build and run sample tests
    const test_step = b.step("test", "Run the test suite");
    test_step.dependOn(&run_tests.step);

    // `zig build run` - alias for test
    const run_step = b.step("run", "Run the test suite");
    run_step.dependOn(&run_tests.step);
}
