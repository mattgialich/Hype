// Metal renderer interface — called from the Swift MTKView delegate.
// All Metal objects are opaque pointers passed through from Swift/ObjC.
// We never import Metal.h here — Swift owns those handles.

const std = @import("std");
const Mat4 = @import("../math/vec.zig").Mat4;
const Vec3 = @import("../math/vec.zig").Vec3;
const Particles = @import("particles.zig");

// Matches FrameUniforms in world.metal
pub const FrameUniforms = extern struct {
    view_proj:     [16]f32,
    view_proj_inv: [16]f32,
    camera_pos:    [3]f32,
    time:          f32,
    resolution:    [2]f32,
    walk_phase:    f32    = 0,
    _pad:          f32    = 0,
};

// Per-object draw call data uploaded to MTLBuffer
pub const DrawCall = extern struct {
    model_matrix: [16]f32,
    color:        [4]f32,
    fx_flags:     u32,
    mesh_id:      u16,
    _pad:         [2]u8 = .{0, 0},
};

// Camera state — updated each frame, owned by Zig
pub const Camera = struct {
    target:   Vec3 = Vec3.zero,
    // POE2-style: fixed angle, high up, looking down slightly
    offset:   Vec3 = Vec3{ .x = 0, .y = 32, .z = 20 },
    fov:      f32  = 50.0 * (std.math.pi / 180.0),
    near:     f32  = 0.1,
    far:      f32  = 500.0,

    pub fn view_matrix(cam: *const Camera) Mat4 {
        const eye = cam.target.add(cam.offset);
        return Mat4.look_at(eye, cam.target, Vec3.up);
    }

    pub fn proj_matrix(cam: *const Camera, aspect: f32) Mat4 {
        return Mat4.perspective(cam.fov, aspect, cam.near, cam.far);
    }

    pub fn smooth_follow(cam: *Camera, target: Vec3, dt: f32) void {
        const speed = 3.0; // looser follow so the player visibly leads the camera
        cam.target = cam.target.lerp(target, 1.0 - std.math.exp(-speed * dt));
    }
};

// Render state passed to Swift each frame
pub const RenderFrame = struct {
    uniforms:     FrameUniforms,
    draws:        []DrawCall,
    draw_count:   u32,
    emitters:     []Particles.GpuEmitter,
    emitter_count: u32,
};

pub const Renderer = struct {
    camera:      Camera = .{},
    draw_buf:    [4096]DrawCall = undefined,
    draw_count:  u32 = 0,

    pub fn begin_frame(r: *Renderer) void {
        r.draw_count = 0;
    }

    pub fn push_draw(r: *Renderer, call: DrawCall) void {
        if (r.draw_count >= 4096) return;
        r.draw_buf[r.draw_count] = call;
        r.draw_count += 1;
    }

    pub fn build_frame(
        r: *Renderer,
        aspect: f32,
        time: f32,
        width: f32,
        height: f32,
        particles: *Particles.ParticleSystem,
    ) RenderFrame {
        const view = r.camera.view_matrix();
        const proj = r.camera.proj_matrix(aspect);
        const vp   = proj.mul(view);

        return RenderFrame{
            .uniforms = FrameUniforms{
                .view_proj     = vp.m,
                .view_proj_inv = Mat4.identity.m, // TODO: invert for deferred pass
                .camera_pos    = .{
                    r.camera.target.x + r.camera.offset.x,
                    r.camera.target.y + r.camera.offset.y,
                    r.camera.target.z + r.camera.offset.z,
                },
                .time          = time,
                .resolution    = .{ width, height },
            },
            .draws         = r.draw_buf[0..r.draw_count],
            .draw_count    = r.draw_count,
            .emitters      = particles.emitters[0..particles.emitter_count],
            .emitter_count = @intCast(particles.emitter_count),
        };
    }
};
