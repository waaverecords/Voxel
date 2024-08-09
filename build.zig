const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "voxel",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const lib = b.addStaticLibrary(.{
        .name = "zglfw",
        .root_source_file = b.path("libs/zglfw/glfw.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkSystemLibrary("gdi32");
    lib.linkSystemLibrary("glfw3");
    lib.linkLibC();
    b.installArtifact(lib);
    exe.linkLibrary(lib);
    exe.root_module.addImport("glfw", b.createModule(.{ .root_source_file = b.path("libs/zglfw/glfw.zig") }));

    const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core
    });
    exe.root_module.addImport("gl", gl_bindings);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
