// Copyright (C) 2020-2026 by
// David Turner, Robert Wilhelm, and Werner Lemberg.
//
// This file is part of the FreeType project, and may only be used, modified,
// and distributed under the terms of the FreeType project license,
// LICENSE.TXT.  By continuing to use, modify, or distribute this file you
// indicate that you have read the license and understand and accept it
// fully.

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var arg_it = try init.minimal.args.iterateAllocator(arena);

    var opt_input_source: ?[]const u8 = null;
    var opt_output_file: ?std.Io.File = null;
    defer if (opt_output_file) |file| file.close(io);

    var options: std.array_hash_map.String(bool) = .empty;

    _ = arg_it.skip();

    while (arg_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try std.Io.File.stdout().writeStreamingAll(io, usage);
            return;
        } else if (std.mem.cutPrefix(u8, arg, "--output=")) |output_file_path| {
            if (opt_output_file != null) std.process.fatal("expected at most one --output argument", .{});
            opt_output_file = std.Io.Dir.cwd().createFile(io, output_file_path, .{ .exclusive = true }) catch |err|
                std.process.fatal("failed to create output file '{s}': {t}", .{ arg, err });
        } else if (std.mem.cutPrefix(u8, arg, "--enable=")) |option_name| {
            const gop = try options.getOrPutValue(arena, try arena.dupe(u8, option_name), true);
            if (gop.found_existing) std.process.fatal("option '{s}' must only be specified once", .{option_name});
        } else if (std.mem.cutPrefix(u8, arg, "--disable=")) |option_name| {
            const gop = try options.getOrPutValue(arena, try arena.dupe(u8, option_name), false);
            if (gop.found_existing) std.process.fatal("option '{s}' must only be specified once", .{option_name});
        } else {
            if (opt_input_source != null) std.process.fatal("expected only one positional argument", .{});
            opt_input_source = std.Io.Dir.cwd().readFileAlloc(io, arg, arena, .unlimited) catch |err|
                std.process.fatal("failed to open input file '{s}': {t}", .{ arg, err });
        }
    }

    const output_file = opt_output_file orelse std.Io.File.stdout();
    const input_source = opt_input_source orelse std.process.fatal("missing positional argument", .{});

    var options_seen: std.array_hash_map.String(void) = .empty;

    var write_buffer: [4096]u8 = undefined;
    var output_file_writer = output_file.writer(io, &write_buffer);
    const writer = &output_file_writer.interface;

    var line_it = std.mem.splitScalar(u8, input_source, '\n');
    while (line_it.next()) |untrimmed_line| {
        const line = std.mem.trimEnd(u8, untrimmed_line, &std.ascii.whitespace);

        const name, const is_enabled = blk: {
            if (std.mem.cutPrefix(u8, line, "/* #define ")) |no_prefix| {
                if (std.mem.cutSuffix(u8, no_prefix, " */")) |cut_line| {
                    const name = std.mem.trim(u8, cut_line, &std.ascii.whitespace);
                    break :blk .{ name, false };
                }
            }
            if (std.mem.cutPrefix(u8, line, "#define ")) |name| {
                break :blk .{ name, true };
            }
            if (std.mem.cutPrefix(u8, line, "#undef ")) |name| {
                break :blk .{ name, false };
            }

            try writer.writeAll(line);
            try writer.writeByte('\n');
            continue;
        };

        const gop = try options_seen.getOrPut(arena, name);
        if (gop.found_existing) std.process.fatal("found duplicate definition of '{s}' in input file", .{name});

        if (options.fetchSwapRemove(name)) |kv| {
            const want_enabled = kv.value;
            if (is_enabled and !want_enabled) {
                try writer.writeAll("#undef ");
                try writer.writeAll(name);
                try writer.writeByte('\n');
                continue;
            }
            if (!is_enabled and want_enabled) {
                try writer.writeAll("#define ");
                try writer.writeAll(name);
                try writer.writeByte('\n');
                continue;
            }
        }

        try writer.writeAll(line);
        try writer.writeByte('\n');
    }

    if (options.count() > 0) {
        std.log.err("Could not find options in input file: ", .{});
        for (options.keys()) |name| {
            std.log.err("  - {s}", .{name});
        }
        std.process.exit(1);
    }

    try output_file_writer.end();
}

const usage =
    \\usage: process_ftoption_h [-h] [--output OUTPUT] [--enable ENABLE] [--disable DISABLE] FTOPTION_H
    \\
    \\Toggle settings in `ftoption.h` file based on command-line arguments. This script takes an `ftoption.h` file as input and rewrites `#define`/`#undef` lines in it based on `--enable=CONFIG_VARNAME`
    \\or `--disable=CONFIG_VARNAME` arguments passed to it, where `CONFIG_VARNAME` is configuration variable name, such as `FT_CONFIG_OPTION_USE_LZW`, that may appear in the file. Note that if one of
    \\`CONFIG_VARNAME` is not found in the input file, this script exits with an error message listing the missing variable names.
    \\
    \\positional arguments:
    \\  FTOPTION_H         Path to input ftoption.h file.
    \\
    \\options:
    \\  -h, --help         show this help message and exit
    \\  --output OUTPUT    Output to file instead of stdout.
    \\  --enable ENABLE    Enable a given build option (e.g. FT_CONFIG_OPTION_USE_LZW).
    \\  --disable DISABLE  Disable a given build option.
    \\
;
