const std = @import("std");
const zcc = @import("compile_commands");

fn generate_files(b: *std.Build) *std.Build.Step.WriteFile {
    const gen_wf = b.addWriteFiles();

    _ = gen_wf.add("version.h",
        \\#pragma once
        \\
        \\#define DXVK_VERSION "2.4.1-openRBRVR-multiview"
        \\
    );

    _ = gen_wf.add("buildenv.h",
        \\#pragma once
        \\
        \\#define DXVK_TARGET "x86"
        \\#define DXVK_COMPILER "zig"
        \\#define DXVK_COMPILER_VERSION "0.15"
        \\
    );

    return gen_wf;
}

fn compile_shaders(b: *std.Build) *std.Build.Step.WriteFile {
    const shader_wf = b.addWriteFiles();

    const dxvk_shaders = [_][]const u8{
        "src/dxvk/shaders/dxvk_blit_frag_1d.frag",
        "src/dxvk/shaders/dxvk_blit_frag_2d.frag",
        "src/dxvk/shaders/dxvk_blit_frag_3d.frag",
        "src/dxvk/shaders/dxvk_clear_buffer_u.comp",
        "src/dxvk/shaders/dxvk_clear_buffer_f.comp",
        "src/dxvk/shaders/dxvk_clear_image1d_u.comp",
        "src/dxvk/shaders/dxvk_clear_image1d_f.comp",
        "src/dxvk/shaders/dxvk_clear_image1darr_u.comp",
        "src/dxvk/shaders/dxvk_clear_image1darr_f.comp",
        "src/dxvk/shaders/dxvk_clear_image2d_u.comp",
        "src/dxvk/shaders/dxvk_clear_image2d_f.comp",
        "src/dxvk/shaders/dxvk_clear_image2darr_u.comp",
        "src/dxvk/shaders/dxvk_clear_image2darr_f.comp",
        "src/dxvk/shaders/dxvk_clear_image3d_u.comp",
        "src/dxvk/shaders/dxvk_clear_image3d_f.comp",
        "src/dxvk/shaders/dxvk_copy_buffer_image.comp",
        "src/dxvk/shaders/dxvk_copy_color_1d.frag",
        "src/dxvk/shaders/dxvk_copy_color_2d.frag",
        "src/dxvk/shaders/dxvk_copy_color_ms.frag",
        "src/dxvk/shaders/dxvk_copy_depth_stencil_1d.frag",
        "src/dxvk/shaders/dxvk_copy_depth_stencil_2d.frag",
        "src/dxvk/shaders/dxvk_copy_depth_stencil_ms.frag",
        "src/dxvk/shaders/dxvk_dummy_frag.frag",
        "src/dxvk/shaders/dxvk_fullscreen_geom.geom",
        "src/dxvk/shaders/dxvk_fullscreen_vert.vert",
        "src/dxvk/shaders/dxvk_fullscreen_layer_vert.vert",
        "src/dxvk/shaders/dxvk_pack_d24s8.comp",
        "src/dxvk/shaders/dxvk_pack_d32s8.comp",
        "src/dxvk/shaders/dxvk_present_frag.frag",
        "src/dxvk/shaders/dxvk_present_frag_blit.frag",
        "src/dxvk/shaders/dxvk_present_frag_ms.frag",
        "src/dxvk/shaders/dxvk_present_frag_ms_amd.frag",
        "src/dxvk/shaders/dxvk_present_vert.vert",
        "src/dxvk/shaders/dxvk_resolve_frag_d.frag",
        "src/dxvk/shaders/dxvk_resolve_frag_ds.frag",
        "src/dxvk/shaders/dxvk_resolve_frag_f.frag",
        "src/dxvk/shaders/dxvk_resolve_frag_f_amd.frag",
        "src/dxvk/shaders/dxvk_resolve_frag_i.frag",
        "src/dxvk/shaders/dxvk_resolve_frag_u.frag",
        "src/dxvk/shaders/dxvk_unpack_d24s8_as_d32s8.comp",
        "src/dxvk/shaders/dxvk_unpack_d24s8.comp",
        "src/dxvk/shaders/dxvk_unpack_d32s8.comp",
        "src/dxvk/hud/shaders/hud_graph_frag.frag",
        "src/dxvk/hud/shaders/hud_graph_vert.vert",
        "src/dxvk/hud/shaders/hud_text_frag.frag",
        "src/dxvk/hud/shaders/hud_text_vert.vert",
    };

    const d3d9_shaders = [_][]const u8{
        "src/d3d9/shaders/d3d9_convert_yuy2_uyvy.comp",
        "src/d3d9/shaders/d3d9_convert_l6v5u5.comp",
        "src/d3d9/shaders/d3d9_convert_x8l8v8u8.comp",
        "src/d3d9/shaders/d3d9_convert_a2w10v10u10.comp",
        "src/d3d9/shaders/d3d9_convert_w11v11u10.comp",
        "src/d3d9/shaders/d3d9_convert_nv12.comp",
        "src/d3d9/shaders/d3d9_convert_yv12.comp",
    };

    const all_shaders = dxvk_shaders ++ d3d9_shaders;

    // Compile all shaders
    for (all_shaders) |shader| {
        const basename = std.fs.path.stem(shader);
        const output_header = b.fmt("{s}.h", .{basename});
        const shader_dir = std.fs.path.dirname(shader) orelse ".";

        const run_step = b.addSystemCommand(&.{
            "glslangValidator",
            "--quiet",
            "--target-env",
            "vulkan1.3",
            "--vn",
            basename,
            b.fmt("-I{s}", .{shader_dir}),
            "-o",
        });

        const output = run_step.addOutputFileArg(output_header);
        run_step.addFileArg(b.path(shader));

        _ = shader_wf.addCopyFile(output, output_header);
    }

    return shader_wf;
}

const DisplayInfo = struct {
    lib: *std.Build.Step.Compile,
    pnp_gen_step: *std.Build.Step,
};

fn build_displayinfo(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) DisplayInfo {
    const libdisplay_info_dep = b.dependency("libdisplay_info", .{});

    const pnp_gen = b.addSystemCommand(&.{"python3"});
    pnp_gen.addFileArg(libdisplay_info_dep.path("tool/gen-search-table.py"));
    pnp_gen.addFileArg(libdisplay_info_dep.path("pnp.ids"));

    const pnp_id_table_c = pnp_gen.addOutputFileArg("pnp-id-table.c");
    pnp_gen.addArg("pnp_id_table");

    const di = b.addLibrary(.{
        .linkage = .static,
        .name = "display-info",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    di.addCSourceFiles(.{
        .root = libdisplay_info_dep.path("."),
        .files = &.{
            "cta.c",
            "displayid.c",
            "dmt-table.c",
            "edid.c",
            "gtf.c",
            "info.c",
            "log.c",
            "memory-stream.c",
        },
    });
    di.addCSourceFile(.{ .file = pnp_id_table_c });

    const msvc = false; // TODO
    if (msvc) {
        di.root_module.addCMacro("static_array", "");
        di.root_module.addCMacro("ssize_t", "intptr_t");
    } else {
        di.root_module.addCMacro("static_array", "static");
        di.root_module.addCMacro("_POSIX_C_SOURCE", "200809L");
    }

    di.addIncludePath(libdisplay_info_dep.path("include"));

    return .{ .lib = di, .pnp_gen_step = &pnp_gen.step };
}

fn build_spirv(b: *std.Build, include_paths: []const std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const spirv = b.addLibrary(.{
        .linkage = .static,
        .name = "spirv",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    spirv.addCSourceFiles(.{
        .files = &.{
            "src/spirv/spirv_code_buffer.cpp",
            "src/spirv/spirv_compression.cpp",
            "src/spirv/spirv_module.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        spirv.addIncludePath(path);
    }

    return spirv;
}

fn build_vulkan_loader(b: *std.Build, include_paths: []const std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const vulkan_loader = b.addLibrary(.{
        .linkage = .static,
        .name = "vkcommon",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    vulkan_loader.addCSourceFiles(.{
        .files = &.{
            "src/vulkan/vulkan_loader.cpp",
            "src/vulkan/vulkan_names.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        vulkan_loader.addIncludePath(path);
    }

    return vulkan_loader;
}

fn build_util(b: *std.Build, include_paths: []const std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const util = b.addLibrary(.{
        .linkage = .static,
        .name = "util",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    util.addCSourceFiles(.{
        .files = &.{
            "src/util/util_env.cpp",
            "src/util/util_string.cpp",
            "src/util/util_fps_limiter.cpp",
            "src/util/util_flush.cpp",
            "src/util/util_gdi.cpp",
            "src/util/util_luid.cpp",
            "src/util/util_matrix.cpp",
            "src/util/util_shared_res.cpp",
            "src/util/util_sleep.cpp",
            "src/util/thread.cpp",
            "src/util/com/com_guid.cpp",
            "src/util/com/com_private_data.cpp",
            "src/util/config/config.cpp",
            "src/util/log/log.cpp",
            "src/util/log/log_debug.cpp",
            "src/util/sha1/sha1_util.cpp",
            "src/util/sync/sync_recursive.cpp",
        },
        .flags = &cppflags,
    });

    util.addCSourceFiles(.{
        .files = &.{
            "src/util/sha1/sha1.c",
        },
        .flags = &cflags,
    });

    for (include_paths) |path| {
        util.addIncludePath(path);
    }

    return util;
}

const Wsi = struct {
    lib: *std.Build.Step.Compile,
    pnp_gen_step: *std.Build.Step,
};

fn build_wsi(b: *std.Build, include_paths: []const std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Wsi {
    const wsi = b.addLibrary(.{
        .linkage = .static,
        .name = "wsi",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    wsi.addCSourceFiles(.{
        .files = &.{
            "src/wsi/wsi_edid.cpp",
            "src/wsi/wsi_platform.cpp",
            "src/wsi/win32/wsi_monitor_win32.cpp",
            "src/wsi/win32/wsi_platform_win32.cpp",
            "src/wsi/win32/wsi_window_win32.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        wsi.addIncludePath(path);
    }

    const di = build_displayinfo(b, target, optimize);
    wsi.linkLibrary(di.lib);

    return .{ .lib = wsi, .pnp_gen_step = di.pnp_gen_step };
}

const Dxvk = struct {
    lib: *std.Build.Step.Compile,
    pnp_gen_step: *std.Build.Step,
};

fn build_dxvk(
    b: *std.Build,
    include_paths: []const std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    gen_wf: *std.Build.Step.WriteFile,
    shader_wf: *std.Build.Step.WriteFile,
) Dxvk {
    const dxvk = b.addLibrary(.{
        .linkage = .static,
        .name = "dxvk",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    dxvk.addCSourceFiles(.{
        .files = &.{
            "src/dxvk/dxvk_adapter.cpp",
            "src/dxvk/dxvk_barrier.cpp",
            "src/dxvk/dxvk_buffer.cpp",
            "src/dxvk/dxvk_cmdlist.cpp",
            "src/dxvk/dxvk_compute.cpp",
            "src/dxvk/dxvk_context.cpp",
            "src/dxvk/dxvk_cs.cpp",
            "src/dxvk/dxvk_data.cpp",
            "src/dxvk/dxvk_descriptor.cpp",
            "src/dxvk/dxvk_device.cpp",
            "src/dxvk/dxvk_device_filter.cpp",
            "src/dxvk/dxvk_extensions.cpp",
            "src/dxvk/dxvk_fence.cpp",
            "src/dxvk/dxvk_format.cpp",
            "src/dxvk/dxvk_framebuffer.cpp",
            "src/dxvk/dxvk_gpu_event.cpp",
            "src/dxvk/dxvk_gpu_query.cpp",
            "src/dxvk/dxvk_graphics.cpp",
            "src/dxvk/dxvk_image.cpp",
            "src/dxvk/dxvk_instance.cpp",
            "src/dxvk/dxvk_lifetime.cpp",
            "src/dxvk/dxvk_memory.cpp",
            "src/dxvk/dxvk_meta_blit.cpp",
            "src/dxvk/dxvk_meta_clear.cpp",
            "src/dxvk/dxvk_meta_copy.cpp",
            "src/dxvk/dxvk_meta_mipgen.cpp",
            "src/dxvk/dxvk_meta_pack.cpp",
            "src/dxvk/dxvk_meta_resolve.cpp",
            "src/dxvk/dxvk_options.cpp",
            "src/dxvk/dxvk_pipelayout.cpp",
            "src/dxvk/dxvk_pipemanager.cpp",
            "src/dxvk/dxvk_platform_exts.cpp",
            "src/dxvk/dxvk_presenter.cpp",
            "src/dxvk/dxvk_queue.cpp",
            "src/dxvk/dxvk_resource.cpp",
            "src/dxvk/dxvk_sampler.cpp",
            "src/dxvk/dxvk_shader.cpp",
            "src/dxvk/dxvk_shader_key.cpp",
            "src/dxvk/dxvk_signal.cpp",
            "src/dxvk/dxvk_sparse.cpp",
            "src/dxvk/dxvk_staging.cpp",
            "src/dxvk/dxvk_state_cache.cpp",
            "src/dxvk/dxvk_stats.cpp",
            "src/dxvk/dxvk_swapchain_blitter.cpp",
            "src/dxvk/dxvk_unbound.cpp",
            "src/dxvk/dxvk_util.cpp",
            "src/dxvk/dxvk_openvr.cpp",
            "src/dxvk/dxvk_openxr.cpp",
            "src/dxvk/hud/dxvk_hud.cpp",
            "src/dxvk/hud/dxvk_hud_font.cpp",
            "src/dxvk/hud/dxvk_hud_item.cpp",
            "src/dxvk/hud/dxvk_hud_renderer.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        dxvk.addIncludePath(path);
    }
    dxvk.addIncludePath(gen_wf.getDirectory());
    dxvk.addIncludePath(shader_wf.getDirectory());

    const wsi = build_wsi(b, include_paths, target, optimize);

    dxvk.linkLibrary(build_util(b, include_paths, target, optimize));
    dxvk.linkLibrary(build_spirv(b, include_paths, target, optimize));
    dxvk.linkLibrary(build_vulkan_loader(b, include_paths, target, optimize));
    dxvk.linkLibrary(wsi.lib);

    return .{ .lib = dxvk, .pnp_gen_step = wsi.pnp_gen_step };
}

fn build_dxso(b: *std.Build, include_paths: []const std.Build.LazyPath, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const dxso = b.addLibrary(.{
        .linkage = .static,
        .name = "dxso",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    dxso.addCSourceFiles(.{
        .files = &.{
            "src/dxso/dxso_common.cpp",
            "src/dxso/dxso_options.cpp",
            "src/dxso/dxso_module.cpp",
            "src/dxso/dxso_reader.cpp",
            "src/dxso/dxso_header.cpp",
            "src/dxso/dxso_ctab.cpp",
            "src/dxso/dxso_util.cpp",
            "src/dxso/dxso_code.cpp",
            "src/dxso/dxso_tables.cpp",
            "src/dxso/dxso_decoder.cpp",
            "src/dxso/dxso_analysis.cpp",
            "src/dxso/dxso_compiler.cpp",
            "src/dxso/dxso_enums.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        dxso.addIncludePath(path);
    }

    return dxso;
}

fn build_d3d9(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const d3d9 = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "d3d9",
        .root_module = b.addModule("d3d9", .{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    const vkheaders = b.dependency("vulkan_headers", .{});
    const spirv_headers = b.dependency("spirv_headers", .{});
    const include_paths: []const std.Build.LazyPath = &.{
        b.path("include"),
        vkheaders.path("include"),
        vkheaders.path("include/vulkan"),
        spirv_headers.path("include"),
        b.dependency("libdisplay_info", .{}).path("include"),
    };

    d3d9.addCSourceFiles(.{
        .files = &.{
            "src/d3d9/d3d9_main.cpp",
            "src/d3d9/d3d9_interface.cpp",
            "src/d3d9/d3d9_adapter.cpp",
            "src/d3d9/d3d9_monitor.cpp",
            "src/d3d9/d3d9_device.cpp",
            "src/d3d9/d3d9_state.cpp",
            "src/d3d9/d3d9_cursor.cpp",
            "src/d3d9/d3d9_swapchain.cpp",
            "src/d3d9/d3d9_format.cpp",
            "src/d3d9/d3d9_common_texture.cpp",
            "src/d3d9/d3d9_constant_buffer.cpp",
            "src/d3d9/d3d9_texture.cpp",
            "src/d3d9/d3d9_surface.cpp",
            "src/d3d9/d3d9_volume.cpp",
            "src/d3d9/d3d9_common_buffer.cpp",
            "src/d3d9/d3d9_buffer.cpp",
            "src/d3d9/d3d9_shader.cpp",
            "src/d3d9/d3d9_vertex_declaration.cpp",
            "src/d3d9/d3d9_query.cpp",
            "src/d3d9/d3d9_multithread.cpp",
            "src/d3d9/d3d9_options.cpp",
            "src/d3d9/d3d9_stateblock.cpp",
            "src/d3d9/d3d9_sampler.cpp",
            "src/d3d9/d3d9_util.cpp",
            "src/d3d9/d3d9_initializer.cpp",
            "src/d3d9/d3d9_fixed_function.cpp",
            "src/d3d9/d3d9_names.cpp",
            "src/d3d9/d3d9_swvp_emu.cpp",
            "src/d3d9/d3d9_format_helpers.cpp",
            "src/d3d9/d3d9_hud.cpp",
            "src/d3d9/d3d9_vr.cpp",
            "src/d3d9/d3d9_annotation.cpp",
            "src/d3d9/d3d9_mem.cpp",
            "src/d3d9/d3d9_window.cpp",
            "src/d3d9/d3d9_interop.cpp",
            "src/d3d9/d3d9_on_12.cpp",
            "src/d3d9/d3d9_bridge.cpp",
        },
        .flags = &cppflags,
    });

    for (include_paths) |path| {
        d3d9.addIncludePath(path);
    }

    const gen_wf = generate_files(b);
    const shader_wf = compile_shaders(b);

    d3d9.addIncludePath(gen_wf.getDirectory());
    d3d9.addIncludePath(shader_wf.getDirectory());
    d3d9.addWin32ResourceFile(.{
        .file = b.path("src/d3d9/version.rc"),
    });

    const dxvk = build_dxvk(b, include_paths, target, optimize, gen_wf, shader_wf);
    d3d9.linkLibrary(dxvk.lib);
    d3d9.linkLibrary(build_dxso(b, include_paths, target, optimize));

    d3d9.linkSystemLibrary("gdi32");
    // d3d9.linkSystemLibrary("user32");
    // d3d9.linkSystemLibrary("ws2_32");
    // d3d9.linkSystemLibrary("winmm");

    d3d9.installHeadersDirectory(vkheaders.path("include"), "", .{});
    d3d9.installHeadersDirectory(b.path("src/d3d9"), "", .{});

    d3d9.dll_export_fns = true;

    // For compile_commands.json
    var targets: std.ArrayListUnmanaged(*std.Build.Step.Compile) = .empty;
    targets.append(b.allocator, d3d9) catch @panic("OOM");
    const cdb_step = zcc.createStep(b, "cdb", targets.toOwnedSlice(b.allocator) catch @panic("OOM"));
    // cdb needs generated files to exist before it can resolve include paths
    cdb_step.dependOn(&gen_wf.step);
    cdb_step.dependOn(&shader_wf.step);
    cdb_step.dependOn(dxvk.pnp_gen_step);

    return d3d9;
}

const cflags = [_][]const u8{
    "-DNOMINMAX",
    "-DDXVK_WSI_WIN32",
    "-msse",
    "-msse2",
    "-msse3",
    "-mfpmath=sse",
    "-Wimplicit-fallthrough",
    "-Wno-unused-parameter",
    "-Wno-missing-field-initializers",
    "-Wno-unused-private-field",
    "-Wno-microsoft-exception-spec",
    "-Wno-extern-c-compat",
    "-Wno-unused-const-variable",
    "-Wno-missing-braces",
    "-Wno-cast-function-type",
};

const ldflags = [_][]const u8{
    "-static",
    "-static-libgcc",
    "-static-libstdc++",
    "-Wl,--file-alignment=4096",
    "-Wl,--enable-stdcall-fixup",
    "-Wl,--kill-at",
};

const cppflags = cflags ++ .{
    "-std=c++17",
};

pub fn build(b: *std.Build) void {
    const default_target = std.Target.Query{ .cpu_arch = .x86, .os_tag = .windows, .abi = .gnu };
    const target = b.standardTargetOptions(.{
        .default_target = default_target,
    });
    const optimize = b.standardOptimizeOption(.{});

    const d3d9 = build_d3d9(b, target, optimize);
    b.installArtifact(d3d9);

    const build_step = b.step("d3d9", "Build d3d9.dll");
    build_step.dependOn(&d3d9.step);
    b.default_step.dependOn(build_step);
}
