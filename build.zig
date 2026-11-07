const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const libpng_enabled = b.option(bool, "enable-libpng", "Build libpng") orelse false;

    const upstream = b.dependency("freetype", .{});
    const lib = b.addLibrary(.{
        .name = "freetype",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = .off,
        }),
    });
    lib.root_module.addIncludePath(upstream.path("include"));
    lib.root_module.addCMacro("FT2_BUILD_LIBRARY", "1");
    lib.root_module.addCMacro("HAVE_UNISTD_H", "1");
    lib.root_module.addCMacro("HAVE_FCNTL_H", "1");

    const flags: []const []const u8 = &.{};

    if (b.systemIntegrationOption("zlib", .{})) {
        lib.root_module.linkSystemLibrary("z", .{});
        lib.root_module.addCMacro("FT_CONFIG_OPTION_SYSTEM_ZLIB", "1");
    } else if (b.lazyDependency("zlib", .{
        .target = target,
        .optimize = optimize,
    })) |zlib_dependency| {
        lib.root_module.linkLibrary(zlib_dependency.artifact("z"));
    }

    if (libpng_enabled) {
        lib.root_module.addCMacro("FT_CONFIG_OPTION_USE_PNG", "1");
        if (b.systemIntegrationOption("libpng", .{})) {
            lib.root_module.linkSystemLibrary("png", .{});
        } else if (b.lazyDependency("libpng", .{
            .target = target,
            .optimize = optimize,
        })) |libpng_dependency| {
            lib.root_module.linkLibrary(libpng_dependency.artifact("png"));
        }
    }

    lib.root_module.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = srcs,
        .flags = flags,
    });

    switch (target.result.os.tag) {
        .linux => lib.root_module.addCSourceFile(.{
            .file = upstream.path("builds/unix/ftsystem.c"),
            .flags = flags,
        }),
        .windows => lib.root_module.addCSourceFile(.{
            .file = upstream.path("builds/windows/ftsystem.c"),
            .flags = flags,
        }),
        else => lib.root_module.addCSourceFile(.{
            .file = upstream.path("src/base/ftsystem.c"),
            .flags = flags,
        }),
    }
    switch (target.result.os.tag) {
        .windows => {
            lib.root_module.addCSourceFile(.{
                .file = upstream.path("builds/windows/ftdebug.c"),
                .flags = flags,
            });
            lib.root_module.addWin32ResourceFile(.{
                .file = upstream.path("src/base/ftver.rc"),
            });
        },
        else => lib.root_module.addCSourceFile(.{
            .file = upstream.path("src/base/ftdebug.c"),
            .flags = flags,
        }),
    }

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
