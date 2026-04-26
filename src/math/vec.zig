// Math primitives — no dependencies, pure Zig

const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub const zero = Vec2{ .x = 0, .y = 0 };

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }
    pub fn sub(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{ .x = v.x * s, .y = v.y * s };
    }
    pub fn len(v: Vec2) f32 {
        return std.math.sqrt(v.x * v.x + v.y * v.y);
    }
    pub fn norm(v: Vec2) Vec2 {
        const l = v.len();
        if (l < 1e-6) return zero;
        return v.scale(1.0 / l);
    }
    pub fn dot(a: Vec2, b: Vec2) f32 {
        return a.x * b.x + a.y * b.y;
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const zero = Vec3{ .x = 0, .y = 0, .z = 0 };
    pub const up    = Vec3{ .x = 0, .y = 1, .z = 0 };

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }
    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }
    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }
    pub fn len(v: Vec3) f32 {
        return std.math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }
    pub fn norm(v: Vec3) Vec3 {
        const l = v.len();
        if (l < 1e-6) return zero;
        return v.scale(1.0 / l);
    }
    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }
    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }
    pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
        return a.add(b.sub(a).scale(t));
    }
};

pub const Vec4 = struct {
    x: f32, y: f32, z: f32, w: f32,
};

// Column-major 4x4 matrix
pub const Mat4 = struct {
    m: [16]f32,

    pub const identity = Mat4{ .m = .{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }};

    pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / std.math.tan(fov_y * 0.5);
        const range_inv = 1.0 / (near - far);
        return Mat4{ .m = .{
            f / aspect, 0, 0,                        0,
            0,          f, 0,                        0,
            0,          0, (far + near) * range_inv, -1,
            0,          0, 2 * far * near * range_inv, 0,
        }};
    }

    pub fn look_at(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = target.sub(eye).norm();
        const r = f.cross(up).norm();
        const u = r.cross(f);
        return Mat4{ .m = .{
            r.x,              u.x,              -f.x,             0,
            r.y,              u.y,              -f.y,             0,
            r.z,              u.z,              -f.z,             0,
            -r.dot(eye),      -u.dot(eye),       f.dot(eye),      1,
        }};
    }

    pub fn translation(v: Vec3) Mat4 {
        var m = Mat4.identity;
        m.m[12] = v.x;
        m.m[13] = v.y;
        m.m[14] = v.z;
        return m;
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var out: Mat4 = undefined;
        for (0..4) |row| {
            for (0..4) |col| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.m[row + k * 4] * b.m[k + col * 4];
                }
                out.m[row + col * 4] = sum;
            }
        }
        return out;
    }
};
