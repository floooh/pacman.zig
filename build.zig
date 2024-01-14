const std = @import("std");
const Build = std.Build;
const OptimizeMode = std.builtin.OptimizeMode;
const sokol = @import("sokol");

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    // special case handling for native vs web build
    if (!target.result.isWasm()) {
        try buildNative(b, target, optimize, dep_sokol);
    } else {
        try buildWeb(b, target, optimize, dep_sokol);
    }
}

// this is the regular build for all native platforms, nothing surprising here
fn buildNative(b: *Build, target: std.Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const pacman = b.addExecutable(.{
        .name = "pacman",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    pacman.root_module.addImport("sokol", dep_sokol.module("sokol"));
    b.installArtifact(pacman);
    const run = b.addRunArtifact(pacman);
    b.step("run", "Run pacman").dependOn(&run.step);
}

// for web builds, the Zig code needs to be built into a library and linked with the Emscripten linker
fn buildWeb(b: *Build, target: std.Build.ResolvedTarget, optimize: OptimizeMode, dep_sokol: *Build.Dependency) !void {
    const pacman = b.addStaticLibrary(.{
        .name = "pacman",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/pacman.zig" },
    });
    pacman.root_module.addImport("sokol", dep_sokol.module("sokol"));

    // create a build step which invokes the Emscripten linker
    const emsdk = dep_sokol.builder.dependency("emsdk", .{});
    const emcc_link_step = try sokol.emLinkStep(b, .{
        .target = target,
        .optimize = optimize,
        .use_webgl2 = true,
        .shell_file_path = dep_sokol.path("src/sokol/web/shell.html").getPath(b),
        .lib_sokol = dep_sokol.artifact("sokol"), // this is the sokol C library
        .lib_main = pacman,
        .emsdk = emsdk,
    });
    // ...and a special run step to start the web build output via 'emrun'
    const emrun_step = sokol.emRunStep(b, .{ .name = "pacman", .emsdk = emsdk });
    emrun_step.step.dependOn(&emcc_link_step.step);
    b.step("run", "Run pacman").dependOn(&emrun_step.step);
}
