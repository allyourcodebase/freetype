const std = @import("std");

pub fn build(b: *std.Build) !void {
    const upstream = b.dependency("freetype", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .static;
    const strip = b.option(bool, "strip", "Omit debug information");
    const pic = b.option(bool, "pic", "Produce Position Independent Code");

    const zlib = b.option(bool, "zlib", "Support reading gzip-compressed font files") orelse true;
    const bzip2 = b.option(bool, "bzip2", "Support reading bzip2-compressed font files") orelse false;
    const png = b.option(bool, "png", "Support color bitmap glyph formats in the PNG format") orelse false;

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
    if (target.result.os.tag == .windows and linkage == .dynamic) mod.addCMacro("DLL_EXPORT", "1");

    const process_ftoption_h = b.addExecutable(.{
        .name = "process-ftoption-h",
        .root_module = b.createModule(.{
            .root_source_file = b.path("process_ftoption_h.zig"),
            .target = b.graph.host,
            .optimize = std.builtin.OptimizeMode.Debug,
            .single_threaded = true,
        }),
    });

    const ftoption_command = b.addRunArtifact(process_ftoption_h);
    ftoption_command.addFileArg(upstream.path("include/freetype/config/ftoption.h"));
    const ftoption_h = ftoption_command.addPrefixedOutputFileArg("--output=", "ftoption.h");
    mod.addIncludePath(ftoption_h.dirname());
    mod.addCMacro("FT_CONFIG_OPTIONS_H", "<ftoption.h>");

    const flags: []const []const u8 = &.{
        "-fvisibility=hidden",
    };

    if (zlib) {
        ftoption_command.addArg("--enable=FT_CONFIG_OPTION_SYSTEM_ZLIB");
        if (b.systemIntegrationOption("zlib", .{})) {
            mod.linkSystemLibrary("z", .{});
        } else if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dependency| {
            mod.linkLibrary(zlib_dependency.artifact("z"));
        }
    } else {
        ftoption_command.addArg("--disable=FT_CONFIG_OPTION_USE_ZLIB");
    }

    if (bzip2) {
        ftoption_command.addArg("--enable=FT_CONFIG_OPTION_USE_BZIP2");
        if (b.systemIntegrationOption("bzip2", .{})) {
            mod.linkSystemLibrary("bz2", .{});
        } else if (b.lazyDependency("bzip2", .{
            .target = target,
            .optimize = optimize,
        })) |bzip2_dependency| {
            mod.linkLibrary(bzip2_dependency.artifact("bz"));
        }
        mod.addCSourceFile(.{
            .file = upstream.path("src/bzip2/ftbzip2.c"),
            .flags = flags,
        });
    }

    if (png) {
        ftoption_command.addArg("--enable=FT_CONFIG_OPTION_USE_PNG");
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
    b.installArtifact(lib);
    lib.installHeader(ftoption_h, "freetype/config/ftoption.h");

    const use_unix_ftsystem_c = target.result.os.tag != .windows;
    if (use_unix_ftsystem_c) {
        const ftconfig_h = b.addConfigHeader(.{
            .style = .{ .autoconf_undef = upstream.path("builds/unix/ftconfig.h.in") },
        }, .{
            .HAVE_UNISTD_H = true, // standard posix header
            .HAVE_FCNTL_H = true, // standard posix header
        });
        mod.addConfigHeader(ftconfig_h);
        mod.addCMacro("FT_CONFIG_CONFIG_H", "<ftconfig.h>");
        lib.installHeader(ftconfig_h.getOutputFile(), "freetype/config/ftconfig.h");
    } else {
        lib.installHeader(upstream.path("include/freetype/config/ftconfig.h"), "freetype/config/ftconfig.h");
    }

    for (headers) |path| {
        lib.installHeader(upstream.path(b.fmt("include/{s}", .{path})), path);
    }
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

const headers: []const []const u8 = &.{
    "ft2build.h",
    "freetype/freetype.h",
    "freetype/ftadvanc.h",
    "freetype/ftbbox.h",
    "freetype/ftbdf.h",
    "freetype/ftbitmap.h",
    "freetype/ftbzip2.h",
    "freetype/ftcache.h",
    "freetype/ftchapters.h",
    "freetype/ftcid.h",
    "freetype/ftcolor.h",
    "freetype/ftdriver.h",
    "freetype/fterrdef.h",
    "freetype/fterrors.h",
    "freetype/ftfntfmt.h",
    "freetype/ftgasp.h",
    "freetype/ftglyph.h",
    "freetype/ftgxval.h",
    "freetype/ftgzip.h",
    "freetype/ftimage.h",
    "freetype/ftincrem.h",
    "freetype/ftlcdfil.h",
    "freetype/ftlist.h",
    "freetype/ftlogging.h",
    "freetype/ftlzw.h",
    "freetype/ftmac.h",
    "freetype/ftmm.h",
    "freetype/ftmodapi.h",
    "freetype/ftmoderr.h",
    "freetype/ftotval.h",
    "freetype/ftoutln.h",
    "freetype/ftparams.h",
    "freetype/ftpfr.h",
    "freetype/ftrender.h",
    "freetype/ftsizes.h",
    "freetype/ftsnames.h",
    "freetype/ftstroke.h",
    "freetype/ftsynth.h",
    "freetype/ftsystem.h",
    "freetype/fttrigon.h",
    "freetype/fttypes.h",
    "freetype/ftwinfnt.h",
    "freetype/otsvg.h",
    "freetype/t1tables.h",
    "freetype/ttnameid.h",
    "freetype/tttables.h",
    "freetype/tttags.h",
    "freetype/config/ftheader.h",
    "freetype/config/ftstdlib.h",
    "freetype/config/integer-types.h",
    "freetype/config/mac-support.h",
    "freetype/config/public-macros.h",
    "freetype/config/ftmodule.h",
};
