const std = @import("std");
const gl = @import("gl");

pub const Vec3 = struct {
    data: [3]f32 = .{0} ** 3,

    pub fn New(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 {
            .data = .{ x, y, z }
        };
    }

    pub fn UnitZ() Vec3 {
        return Vec3.New(0, 0, 1);
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

    pub fn Rotation(radians: f32, axis: Vec3) Mat4 {
        const c = @cos(radians);
        const s = @sin(radians);
        const t = 1.0 - c;
        const x = axis.data[0];
        const y = axis.data[1];
        const z = axis.data[2];

        const length = @sqrt(x * x + y * y + z * z);
        const nx = x / length;
        const ny = y / length;
        const nz = z / length;

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
};

// pub fn Multiply(matrixA: Mat4, matrixB: Mat4) Mat4 {
//     var result = Mat4.Scalar(0);

//     for (0..4) |i| {
//         for (0..4) |j| {
//             var sum: f32 = 0;
//             for (0..4) |k| {
//                 sum += matrixA.data[i * 4 + k] * matrixB.data[k * 4 + j];
//             }
//             result.data[i * 4 + j] = sum;
//         }
//     }

//     return result;
// }