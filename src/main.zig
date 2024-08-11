const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const math = @import("math.zig");

const windowWidth = 800;
const widonwHeight = 640;

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);

    const window: *glfw.Window = try glfw.createWindow(windowWidth, widonwHeight, "Voxel", null, null);
    defer glfw.destroyWindow(window);

    glfw.setInputMode(window, glfw.Cursor, glfw.CursorDisabled);
    _ = glfw.setCursorPosCallback(window, &onMouseMoved);

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    var gl_procs: gl.ProcTable = undefined;
    _ = gl_procs.init(glfw.getProcAddress);
    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    // vertex buffer

    const vertices = [_]f32 {
        -0.5, -0.5, 0,
        0, 0.5, 0,
        0.5, -0.5, 0
    };

    var vertex_buffer: gl.uint = undefined;

    gl.GenBuffers(1, @ptrCast(&vertex_buffer));
    defer gl.DeleteBuffers(1, @ptrCast(&vertex_buffer));

    gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

    // vertext shader

    const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertex_shader);

    const vertex_shader_source =
        \\#version 330 core
        \\
        \\layout (location = 0) in vec3 aPos;
        \\
        \\out vec3 color;
        \\
        \\uniform mat4 model;
        \\uniform mat4 view;
        \\uniform mat4 projection;
        \\
        \\void main() {
        \\   gl_Position = projection * view * model * vec4(aPos, 1.0);
        \\   color = aPos;
        \\}
    ;
    gl.ShaderSource(vertex_shader, 1, &[1][*]const u8 { vertex_shader_source }, null);
    gl.CompileShader(vertex_shader);

    // fragment shader

    const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragment_shader);

    const fragment_shader_source =
        \\#version 330 core
        \\
        \\in vec3 color;
        \\
        \\out vec4 FragColor;
        \\
        \\void main() {
        \\    FragColor = vec4(color, 1.0f);
        \\}
    ;
    gl.ShaderSource(fragment_shader, 1, &[1][*]const u8 { fragment_shader_source}, null);
    gl.CompileShader(vertex_shader);

    // shader program

    const shader_program = gl.CreateProgram();
    defer gl.DeleteProgram(shader_program);

    gl.AttachShader(shader_program, vertex_shader);
    gl.AttachShader(shader_program, fragment_shader);

    gl.LinkProgram(shader_program);
    gl.UseProgram(shader_program);

    // link vertex attributes

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    // coordinate systems

    var model_matrix = math.Mat4.Rotation(std.math.degreesToRadians(0), math.Vec3.Init(0, 0, 0));
    const model_location = gl.GetUniformLocation(shader_program, "model");
    gl.UniformMatrix4fv(model_location, 1, gl.TRUE, &model_matrix.data);

    const projection_matrix = math.Mat4.Perspective(std.math.degreesToRadians(45), windowWidth / widonwHeight, 0.1, 100);
    const projection_location = gl.GetUniformLocation(shader_program, "projection");
    gl.UniformMatrix4fv(projection_location, 1, gl.TRUE, &projection_matrix.data);

    // camera

    var camera_position = math.Vec3.Init(0, 0, 2);
    const camera_up = math.Vec3.UnitY();
    const camera_speed = 0.05;

    // main loop

    var stdout = std.io.getStdOut().writer();
    gl.Enable(gl.DEPTH_TEST);

    var frame_count: i64 = 0;
    var start_time = std.time.microTimestamp();

    while (!glfw.windowShouldClose(window)) {

        // inputs

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
            continue;
        }

        const camera_direction = math.Vec3.Init(
            @cos(std.math.degreesToRadians(camera_yaw)) * @cos(std.math.degreesToRadians(camera_pitch)),
            @sin(std.math.degreesToRadians(camera_pitch)),
            @sin(std.math.degreesToRadians(camera_yaw)) * @cos(std.math.degreesToRadians(camera_pitch))
        ).Normalize();

        if (glfw.getKey(window, glfw.KeyW) == glfw.Press)
            camera_position = camera_position.Add(camera_direction.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyS) == glfw.Press)
            camera_position = camera_position.Substract(camera_direction.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyA) == glfw.Press)
            camera_position = camera_position.Substract(math.Vec3.Cross(camera_direction, camera_up).Normalize().Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyD) == glfw.Press)
            camera_position = camera_position.Add(math.Vec3.Cross(camera_direction, camera_up).Normalize().Multiply(camera_speed));

        var view_matrix = math.Mat4.LookAt(camera_position, math.Vec3.Add(camera_position, camera_direction), camera_up);
        const view_location = gl.GetUniformLocation(shader_program, "view");
        gl.UniformMatrix4fv(view_location, 1, gl.TRUE, &view_matrix.data);

        // rendering

        gl.ClearColor(0, 0, 255, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        frame_count +=1;
        const current_time = std.time.microTimestamp();
        const elasped_time = current_time - start_time;

        if (elasped_time >= 1_000_000) {
            const fps = @divTrunc(frame_count * 1_000_000, elasped_time);
            try stdout.print("fps: {}\n", .{fps});

            start_time = current_time;
            frame_count = 0;
        }

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}

var camera_yaw: f32 = -90;
var camera_pitch: f32 = 0;

var last_x: f64 = windowWidth / 2;
var last_y: f64 = widonwHeight / 2;
const mouse_sensitivity: f64 = 0.1;
var last_init = false;

pub fn onMouseMoved(window: *glfw.Window, x: f64, y: f64) callconv(.C) void {
    _ = window;

    if (!last_init) {
        last_x = x;
        last_y = y;
        last_init = true;
    }

    const x_offset = mouse_sensitivity * (x - last_x);
    const y_offset = mouse_sensitivity * (last_y - y); // reversed since y-coordinates range from bottom to top
    
    last_x = x;
    last_y = y;

    camera_yaw += @as(f32, @floatCast(x_offset));
    camera_pitch += @as(f32, @floatCast(y_offset));

    var stdout = std.io.getStdOut().writer();
    stdout.print("yaw: {}, pitch: {}\n", .{ @as(i32, @intFromFloat(camera_yaw)), @as(i32, @intFromFloat(camera_pitch)) }) catch {};

    if (camera_pitch > 89.99)
        camera_pitch = 89.99;
    if (camera_pitch < -89.99)
        camera_pitch = -89.99;
}