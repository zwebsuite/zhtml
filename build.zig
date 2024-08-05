const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "zhtml",
    //     .root_source_file = b.path("src/zhtml.zig"),
    //     .target = target,
    //     .optimize = optimize
    // });
    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zhtml-demo",
        .root_source_file = b.path("demo.zig"),
        .target = target,
        .optimize = optimize
    });

    const module_vexlib = b.createModule(.{
        .root_source_file = b.path("../vexlib/"++"src/vexlib.zig"),
        .target = target,
        .optimize = optimize
    });
    exe.root_module.addImport("vexlib", module_vexlib);

    b.installArtifact(exe);
}
