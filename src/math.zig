const std = @import("std");
const gl = @import("gl");

pub const Vec3 = struct {
    data: [3]f32 = .{0} ** 3,

    pub fn Init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 {
            .data = .{ x, y, z }
        };
    }

    pub fn UnitX() Vec3 {
        return Vec3.Init(1, 0, 0);
    }

    pub fn UnitY() Vec3 {
        return Vec3.Init(0, 1, 0);
    }

    pub fn UnitZ() Vec3 {
        return Vec3.Init(0, 0, 1);
    }

    pub fn Add(vecA: Vec3, vecB: Vec3) Vec3 {
        return Vec3.Init(
            vecA.data[0] + vecB.data[0],
            vecA.data[1] + vecB.data[1],
            vecA.data[2] + vecB.data[2]
        );
    }

    pub fn Substract(vecA: Vec3, vecB: Vec3) Vec3 {
        return Vec3.Add(vecA, vecB.Invert());
    }

    pub fn Multiply(vec: Vec3, scalar: f32) Vec3 {
        return Vec3.Init(
            vec.data[0] * scalar, 
            vec.data[1] * scalar, 
            vec.data[2] * scalar
        );
    }

    pub fn Cross(vecA: Vec3, vecB: Vec3) Vec3 {
        return Vec3.Init(
            vecA.data[1] * vecB.data[2] - vecA.data[2] * vecB.data[1],
            vecA.data[2] * vecB.data[0] - vecA.data[0] * vecB.data[2],
            vecA.data[0] * vecB.data[1] - vecA.data[1] * vecB.data[0]
        );
    }

    pub fn Normalize(vec: Vec3) Vec3 {
        const x = vec.data[0];
        const y = vec.data[1];
        const z = vec.data[2];

        const length = @sqrt(x * x + y * y + z * z);

        if (length == 0)
            return Vec3{};

        return Vec3.Init(x / length, y / length, z / length);
    }

    pub fn Invert(vec: Vec3) Vec3 {
        return Vec3.Init(-vec.data[0], -vec.data[1], -vec.data[2]);
    }
};

pub const Mat4 = struct {
    data: [16]f32 = .{0} ** 16,

    pub fn Scalar(i: f32) Mat4 {
        return Mat4 {
            .data = .{
                i, 0, 0, 0,
                0, i, 0, 0,
                0, 0, i, 0,
                0, 0, 0, i,
            }
        };
    }

    pub fn Identity() Mat4 {
        return Mat4.Scalar(1);
    }

    pub fn Multiply(matrixA: Mat4, matrixB: Mat4) Mat4 {
        var result = Mat4.Scalar(0);

        for (0..4) |i| {
            for (0..4) |j| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += matrixA.data[i * 4 + k] * matrixB.data[k * 4 + j];
                }
                result.data[i * 4 + j] = sum;
            }
        }

        return result;
    }

    pub fn Rotation(radians: f32, axis: Vec3) Mat4 {
        const c = @cos(radians);
        const s = @sin(radians);
        const t = 1.0 - c;

        const normalized_axis = Vec3.Normalize(axis);

        const nx = normalized_axis.data[0];
        const ny = normalized_axis.data[1];
        const nz = normalized_axis.data[2];

        return Mat4{
            .data = .{
                t * nx * nx + c,    t * nx * ny - s * nz,  t * nx * nz + s * ny, 0,
                t * nx * ny + s * nz, t * ny * ny + c,    t * ny * nz - s * nx, 0,
                t * nx * nz - s * ny, t * ny * nz + s * nx, t * nz * nz + c, 0,
                0, 0, 0, 1
            },
        };
    }

    pub fn Translation(translation: Vec3) Mat4 {
        const x = translation.data[0];
        const y = translation.data[1];
        const z = translation.data[2];

        return Mat4 {
            .data = .{
                1, 0, 0, x,
                0, 1, 0, y,
                0, 0, 1, z,
                0, 0, 0, 1,
            }
        };
    }

    pub fn Perspective(fovRadians: f32, aspectRatio: f32, nearPlane: f32, farPlane: f32) Mat4 {
        const f = @tan(fovRadians * 0.5);
        const range = nearPlane - farPlane;

        return Mat4 {
            .data = .{
                1.0 / (aspectRatio * f), 0, 0, 0,
                0, 1.0 / f, 0, 0,
                0, 0, (nearPlane + farPlane) / range, 2.0 * nearPlane * farPlane / range,
                0, 0, -1, 0,
            },
        };
    }

    pub fn LookAt(position: Vec3, target: Vec3, up: Vec3) Mat4 {
        const cam_direction = Vec3.Substract(position, target).Normalize();
        const cam_right = Vec3.Cross(up, cam_direction).Normalize();
        const cam_up = Vec3.Cross(cam_direction, cam_right);

        const coord_space = Mat4 {
            .data = .{
                cam_right.data[0], cam_right.data[1], cam_right.data[2], 0,
                cam_up.data[0], cam_up.data[1], cam_up.data[2], 0,
                cam_direction.data[0], cam_direction.data[1], cam_direction.data[2], 0,
                0, 0, 0, 1
            }
        };

        return Mat4.Multiply(coord_space, Mat4.Translation(position.Invert()));
    }
};