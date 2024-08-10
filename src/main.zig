const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);

    const window: *glfw.Window = try glfw.createWindow(800, 640, "Voxel", null, null);
    defer glfw.destroyWindow(window);

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
        \\void main() {
        \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
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
        \\out vec4 FragColor;
        \\
        \\void main() {
        \\    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
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

    // linking vertex attributes

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    while (!glfw.windowShouldClose(window)) {
        gl.ClearColor(0, 0, 255, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}