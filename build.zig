const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    // iOS device (arm64)
    const device_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .aarch64, .os_tag = .ios }),
        .optimize = optimize,
    });
    const device_lib = b.addLibrary(.{
        .name = "mach5game",
        .root_module = device_mod,
        .linkage = .static,
    });
    b.installArtifact(device_lib);

    // iOS simulator (arm64-apple-ios-simulator)
    const sim_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .aarch64, .os_tag = .ios, .abi = .simulator }),
        .optimize = optimize,
    });
    const sim_lib = b.addLibrary(.{
        .name = "mach5game-sim",
        .root_module = sim_mod,
        .linkage = .static,
    });

    // Install sim lib into zig-out/lib-sim/
    const install_sim = b.addInstallLibFile(sim_lib.getEmittedBin(), "sim/libmach5game.a");
    b.getInstallStep().dependOn(&install_sim.step);

    // Host unit tests (entity logic — no Apple deps)
    const host_target = b.standardTargetOptions(.{});
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/game/entity.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{
        .name = "entity_tests",
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    b.step("test", "Run unit tests").dependOn(&run_tests.step);
}
