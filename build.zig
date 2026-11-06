const std = @import("std");

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("freetype", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlib_enabled = b.option(bool, "enable-zlib", "Support reading gzip-compressed font files") orelse true;
    const libpng_enabled = b.option(bool, "enable-libpng", "Build libpng") orelse false;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = .off,
    });
    mod.addIncludePath(upstream.path("include"));
    mod.addCMacro("FT2_BUILD_LIBRARY", "1");
    mod.addCMacro("HAVE_UNISTD_H", "1");
    mod.addCMacro("HAVE_FCNTL_H", "1");

    const flags: []const []const u8 = &.{
        "-fvisibility=hidden",
    };

    if (zlib_enabled) {
        mod.addCMacro("FT_CONFIG_OPTION_SYSTEM_ZLIB", "1");
        if (b.systemIntegrationOption("zlib", .{})) {
            mod.linkSystemLibrary("z", .{});
        } else if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dependency| {
            mod.linkLibrary(zlib_dependency.artifact("z"));
        }
    }

    if (libpng_enabled) {
        mod.addCMacro("FT_CONFIG_OPTION_USE_PNG", "1");
        if (b.systemIntegrationOption("libpng", .{})) {
            mod.linkSystemLibrary("png", .{});
        } else if (b.lazyDependency("libpng", .{
            .target = target,
            .optimize = optimize,
        })) |libpng_dependency| {
            mod.linkLibrary(libpng_dependency.artifact("png"));
        }
    }

    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = srcs,
        .flags = flags,
    });

    switch (target.result.os.tag) {
        .linux => mod.addCSourceFile(.{
            .file = upstream.path("builds/unix/ftsystem.c"),
            .flags = flags,
        }),
        .windows => mod.addCSourceFile(.{
            .file = upstream.path("builds/windows/ftsystem.c"),
            .flags = flags,
        }),
        else => mod.addCSourceFile(.{
            .file = upstream.path("src/base/ftsystem.c"),
            .flags = flags,
        }),
    }
    switch (target.result.os.tag) {
        .windows => {
            mod.addCSourceFile(.{
                .file = upstream.path("builds/windows/ftdebug.c"),
                .flags = flags,
            });
            mod.addWin32ResourceFile(.{
                .file = upstream.path("src/base/ftver.rc"),
            });
        },
        else => mod.addCSourceFile(.{
            .file = upstream.path("src/base/ftdebug.c"),
            .flags = flags,
        }),
    }

    const lib = b.addLibrary(.{
        .name = "freetype",
        .linkage = .static,
        .root_module = mod,
    });

    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{".h"} },
    );

    b.installArtifact(lib);
}

const srcs: []const []const u8 = &.{
    "src/autofit/autofit.c",
    "src/base/ftbase.c",
    "src/base/ftbbox.c",
    "src/base/ftbdf.c",
    "src/base/ftbitmap.c",
    "src/base/ftcid.c",
    "src/base/ftfstype.c",
    "src/base/ftgasp.c",
    "src/base/ftglyph.c",
    "src/base/ftgxval.c",
    "src/base/ftinit.c",
    "src/base/ftmm.c",
    "src/base/ftotval.c",
    "src/base/ftpatent.c",
    "src/base/ftpfr.c",
    "src/base/ftstroke.c",
    "src/base/ftsynth.c",
    "src/base/fttype1.c",
    "src/base/ftwinfnt.c",
    "src/bdf/bdf.c",
    "src/bzip2/ftbzip2.c",
    "src/cache/ftcache.c",
    "src/cff/cff.c",
    "src/cid/type1cid.c",
    "src/gzip/ftgzip.c",
    "src/lzw/ftlzw.c",
    "src/pcf/pcf.c",
    "src/pfr/pfr.c",
    "src/psaux/psaux.c",
    "src/pshinter/pshinter.c",
    "src/psnames/psnames.c",
    "src/raster/raster.c",
    "src/sdf/sdf.c",
    "src/sfnt/sfnt.c",
    "src/smooth/smooth.c",
    "src/svg/svg.c",
    "src/truetype/truetype.c",
    "src/type1/type1.c",
    "src/type42/type42.c",
    "src/winfonts/winfnt.c",
};
