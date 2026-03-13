const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("rlzig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const editor = b.addModule("editor", .{
        .root_source_file = b.path("src/Editor.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "rlzig", .module = mod },
        },
    });

    const platformer = b.addModule("platformer", .{
        .root_source_file = b.path("src/Platformer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "rlzig", .module = mod},
        },
    });

    const exe = b.addExecutable(.{
        .name = "rlzig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "rlzig", .module = mod },
                .{ .name = "editor", .module = editor },
                .{ .name = "platformer", .module = platformer},
            },
        }),
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    mod.linkLibrary(raylib_artifact);
    mod.addImport("raylib", raylib);
    mod.addImport("raygui", raygui);
    mod.addImport("raygui", raygui);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
