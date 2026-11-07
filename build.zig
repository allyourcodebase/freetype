const std = @import("std");

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("freetype", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pic", "Produce Position Independent Code");

    const zlib_enabled = b.option(bool, "enable-zlib", "Support reading gzip-compressed font files") orelse true;
    const libpng_enabled = b.option(bool, "enable-libpng", "Build libpng") orelse false;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .pic = pic,
        .link_libc = true,
        .sanitize_c = .off,
    });
    mod.addIncludePath(upstream.path("include"));
    mod.addCMacro("FT2_BUILD_LIBRARY", "1");
    mod.addCMacro("HAVE_UNISTD_H", "1");
    mod.addCMacro("HAVE_FCNTL_H", "1");
    if (target.result.os.tag == .windows and linkage == .dynamic) mod.addCMacro("DLL_EXPORT", "1");

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

    if (target.result.os.tag.isDarwin()) {
        mod.addCSourceFile(.{
            .file = upstream.path("src/base/ftmac.c"),
            .flags = flags,
        });
    }

    const lib = b.addLibrary(.{
        .name = "freetype",
        .linkage = linkage,
        .root_module = mod,
    });

    lib.installHeadersDirectory(
        upstream.path("include"),
        "",
        .{ .include_extensions = &.{".h"} },
    );

    b.installArtifact(lib);
}

/// Taken from upstream `docs/INSTALL.ANY`
const srcs: []const []const u8 = &.{
    // zig fmt: off

    // "src/base/ftsystem.c",
    "src/base/ftinit.c",
    // "src/base/ftdebug.c",

    "src/base/ftbase.c",

    "src/base/ftbbox.c",   //  recommended, see <ftbbox.h>
    "src/base/ftglyph.c",  //  recommended, see <ftglyph.h>

    "src/base/ftbdf.c",    //  optional, see <ftbdf.h>
    "src/base/ftbitmap.c", //  optional, see <ftbitmap.h>
    "src/base/ftcid.c",    //  optional, see <ftcid.h>
    "src/base/ftfstype.c", //  optional
    "src/base/ftgasp.c",   //  optional, see <ftgasp.h>
    "src/base/ftgxval.c",  //  optional, see <ftgxval.h>
    "src/base/ftmm.c",     //  optional, see <ftmm.h>
    "src/base/ftotval.c",  //  optional, see <ftotval.h>
    "src/base/ftpatent.c", //  optional
    "src/base/ftpfr.c",    //  optional, see <ftpfr.h>
    "src/base/ftstroke.c", //  optional, see <ftstroke.h>
    "src/base/ftsynth.c",  //  optional, see <ftsynth.h>
    "src/base/fttype1.c",  //  optional, see <t1tables.h>
    "src/base/ftwinfnt.c", //  optional, see <ftwinfnt.h>

    // "src/base/ftmac.c",

    // font drivers (optional; at least one is needed)

    "src/bdf/bdf.c",           // BDF font driver
    "src/cff/cff.c",           // CFF/OpenType font driver
    "src/cid/type1cid.c",      // Type 1 CID-keyed font driver
    "src/pcf/pcf.c",           // PCF font driver
    "src/pfr/pfr.c",           // PFR/TrueDoc font driver
    "src/sfnt/sfnt.c",         // SFNT files support (TrueType & OpenType)
    "src/truetype/truetype.c", // TrueType font driver
    "src/type1/type1.c",       // Type 1 font driver
    "src/type42/type42.c",     // Type 42 font driver
    "src/winfonts/winfnt.c",   // Windows FONT / FNT font driver

    // rasterizers (optional; at least one is needed for vector formats)

    "src/smooth/smooth.c",     // anti-aliasing rasterizer
    "src/raster/raster.c",     // monochrome rasterizer
    "src/sdf/sdf.c",           // Signed Distance Field driver

    // auxiliary modules (optional)

    "src/autofit/autofit.c",   // auto hinting module
    "src/cache/ftcache.c",     // cache sub-system (in beta)
    "src/gzip/ftgzip.c",       // support for compressed fonts (.gz)
    "src/lzw/ftlzw.c",         // support for compressed fonts (.Z)
    "src/bzip2/ftbzip2.c",     // support for compressed fonts (.bz2)
    // "src/gxvalid/gxvalid.c",   // TrueTypeGX/AAT table validation
    // "src/otvalid/otvalid.c",   // OpenType table validation
    "src/psaux/psaux.c",       // PostScript Type 1 parsing
    "src/pshinter/pshinter.c", // PS hinting module
    "src/psnames/psnames.c",   // PostScript glyph names support

    // zig fmt: on
};
