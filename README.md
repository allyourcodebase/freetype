[![CI](https://github.com/allyourcodebase/freetype/actions/workflows/ci.yaml/badge.svg)](https://github.com/allyourcodebase/freetype/actions)

# freetype

This is [freetype](https://freetype.org/) packaged for [Zig](https://ziglang.org/).

## Installation

First, update your `build.zig.zon`:

```
# Initialize a `zig build` project if you haven't already
zig init
zig fetch --save git+https://github.com/allyourcodebase/freetype.git
```

You can then import `freetype` in your `build.zig` with:

```zig
const freetype_dependency = b.dependency("freetype", .{
    .target = target,
    .optimize = optimize,
});
your_exe.root_module.linkLibrary(freetype_dependency.artifact("freetype"));
```
