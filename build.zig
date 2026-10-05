const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    if (target.result.os.tag != .macos) @panic("Gnarlaxx currently targets native macOS");
    const native_dir = b.fmt("build/zig/native/{s}", .{@tagName(optimize)});
    const configure = b.addSystemCommand(&.{ "cmake", "-S", ".", "-B", native_dir, if (optimize == .debug) "-DCMAKE_BUILD_TYPE=Debug" else "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_TESTING=OFF" });
    configure.setCwd(b.path("."));
    const native = b.addSystemCommand(&.{ "cmake", "--build", native_dir, "--target", "sokol_odin", "gnarlaxx_audio", "decoders", "-j", "4" });
    native.setCwd(b.path("."));
    native.step.dependOn(&configure.step);

    const bindings = b.createModule(.{ .root_source_file = b.path("vendor/sokol_zig/root.zig"), .target = target, .optimize = optimize });
    const options = b.addOptions();
    options.addOptionPathUntracked("asset_root", b.path("assets"));
    const audio_api = b.addTranslateC(.{ .root_source_file = b.path("libs/audio/gna_audio.h"), .target = target, .optimize = optimize });
    const module = b.createModule(.{
        .root_source_file = b.path("implementations/zig/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{.{ .name = "sokol", .module = bindings }},
    });
    module.addOptions("options", options);
    module.addImport("gna", audio_api.createModule());
    module.addIncludePath(b.path("libs/audio"));
    module.addObjectFile(b.path(b.fmt("{s}/libsokol_odin.a", .{native_dir})));
    module.addObjectFile(b.path(b.fmt("{s}/libdecoders.a", .{native_dir})));
    module.addObjectFile(b.path(b.fmt("{s}/libs/audio/libgnarlaxx_audio.a", .{native_dir})));
    for ([_][]const u8{ "Cocoa", "QuartzCore", "Metal", "MetalKit", "AudioToolbox" }) |name| module.linkFramework(name, .{});
    const exe = b.addExecutable(.{ .name = "gnarlaxx", .root_module = module });
    exe.step.dependOn(&native.step);
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    b.step("run", "Run the Zig game").dependOn(&run.step);
    const tests = b.addTest(.{ .root_module = module });
    tests.step.dependOn(&native.step);
    const test_run = b.addRunArtifact(tests);
    b.step("test", "Run gameplay, memory, persistence, input and shared-audio tests").dependOn(&test_run.step);
}
