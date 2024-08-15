const math = @import("math.zig");
const std = @import("std");
const gl = @import("gl");

pub const Camera = struct {
    // TODO: put these in a transform component?
    position: math.Vec3 = math.Vec3{},
    rotation: math.Vec3 = math.Vec3{},
    fov: f32 = 90,
    
    up: math.Vec3 = math.Vec3.UnitY(),

    pub fn Direction(self: Camera) math.Vec3 {
        return math.Vec3.Init(
            @cos(std.math.degreesToRadians(self.rotation.y)) * @cos(std.math.degreesToRadians(self.rotation.x)),
            @sin(std.math.degreesToRadians(self.rotation.x)),
            @sin(std.math.degreesToRadians(self.rotation.y)) * @cos(std.math.degreesToRadians(self.rotation.x))
        ).Normalize();
    }

    pub fn update(self: Camera, shader_program: c_uint) void {
        var view_matrix = math.Mat4.LookAt(
            self.position,
            math.Vec3.Add(self.position, self.Direction()),
            self.up
        );
        const view_location = gl.GetUniformLocation(shader_program, "view");
        gl.UniformMatrix4fv(view_location, 1, gl.TRUE, &view_matrix.data);
    }
};