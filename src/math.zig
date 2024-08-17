const std = @import("std");
const gl = @import("gl");

pub const Vec3 = packed struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn Init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 { .x = x, .y = y, .z = z };
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
            vecA.x + vecB.x,
            vecA.y + vecB.y,
            vecA.z + vecB.z
        );
    }

    pub fn substract(vecA: Vec3, vecB: Vec3) Vec3 {
        return Vec3.Add(vecA, vecB.Invert());
    }

    pub fn Multiply(vec: Vec3, scalar: f32) Vec3 {
        return Vec3.Init(
            vec.x * scalar, 
            vec.y * scalar, 
            vec.z * scalar
        );
    }

    pub fn divide(vec: Vec3, scalar: f32) Vec3 {
        return Vec3.Multiply(vec, 1 / scalar);
    }

    pub fn Cross(vecA: Vec3, vecB: Vec3) Vec3 {
        return Vec3.Init(
            vecA.y * vecB.z - vecA.z * vecB.y,
            vecA.z * vecB.x - vecA.x * vecB.z,
            vecA.x * vecB.y - vecA.y * vecB.x
        );
    }

    pub fn Normalize(vec: Vec3) Vec3 {
        const x = vec.x;
        const y = vec.y;
        const z = vec.z;

        const length = @sqrt(x * x + y * y + z * z);

        if (length == 0)
            return Vec3{};

        return Vec3.Init(x / length, y / length, z / length);
    }

    pub fn Invert(vec: Vec3) Vec3 {
        return Vec3.Init(-vec.x, -vec.y, -vec.z);
    }

    pub fn cPtr(self: *const Vec3) *const f32 {
        return &self.x;
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

        const normalized_axis = axis.Normalize();

        const nx = normalized_axis.x;
        const ny = normalized_axis.y;
        const nz = normalized_axis.z;

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
        return Mat4 {
            .data = .{
                1, 0, 0, translation.x,
                0, 1, 0, translation.y,
                0, 0, 1, translation.z,
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
        const cam_direction = Vec3.substract(position, target).Normalize();
        const cam_right = Vec3.Cross(up, cam_direction).Normalize();
        const cam_up = Vec3.Cross(cam_direction, cam_right);

        const coord_space = Mat4 {
            .data = .{
                cam_right.x, cam_right.y, cam_right.z, 0,
                cam_up.x, cam_up.y, cam_up.z, 0,
                cam_direction.x, cam_direction.y, cam_direction.z, 0,
                0, 0, 0, 1
            }
        };

        return Mat4.Multiply(coord_space, Mat4.Translation(position.Invert()));
    }
};