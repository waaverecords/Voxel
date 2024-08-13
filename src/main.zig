// https://sites.google.com/site/letsmakeavoxelengine/home/landcape-creation

const std = @import("std");
const print = std.debug.print;
const allocator = std.heap.c_allocator;
const gl = @import("gl");
const glfw = @import("glfw");
const math = @import("math.zig");
const Camera = @import("camera.zig").Camera;
const EntitiesStorage = @import("ecs.zig").EntitiesStorage;

const windowWidth = 800;
const widonwHeight = 640;

var camera = Camera{};

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
        0.5,  0.5, 0.0,
        0.5, -0.5, 0.0,
        -0.5, -0.5, 0.0,
        -0.5,  0.5, 0.0
    };
    const indices = [_]u32 {
        0, 1, 3,
        1, 2, 3
    };

    var vao: gl.uint = 0;

    gl.GenVertexArrays(1, @ptrCast(&vao));
    defer gl.DeleteVertexArrays(1, @ptrCast(&vao));

    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);

    var vertex_buffer: gl.uint = 0;

    gl.GenBuffers(1, @ptrCast(&vertex_buffer));
    defer gl.DeleteBuffers(1, @ptrCast(&vertex_buffer));

    gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer);
    defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);

    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

    var element_buffer: gl.uint = 0;

    gl.GenBuffers(1, @ptrCast(&element_buffer));
    defer gl.DeleteBuffers(1, @ptrCast(&element_buffer));

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer);
    defer gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    // vertext shader

    const vertexShaderFilePath = try std.fs.cwd().realpathAlloc(allocator, "./src/vert.glsl");
    defer allocator.free(vertexShaderFilePath);

    const vertexShader = try createShaderFromFile(gl.VERTEX_SHADER, vertexShaderFilePath);
    defer gl.DeleteShader(vertexShader);

    // fragment shader

    const fragmentShaderFilePath = try std.fs.cwd().realpathAlloc(allocator, "./src/frag.glsl");
    defer allocator.free(fragmentShaderFilePath);

    const fragmentShader = try createShaderFromFile(gl.FRAGMENT_SHADER, fragmentShaderFilePath);
    defer gl.DeleteShader(fragmentShader);

    // shader program

    const shader_program = gl.CreateProgram();
    defer gl.DeleteProgram(shader_program);

    gl.AttachShader(shader_program, vertexShader);
    gl.AttachShader(shader_program, fragmentShader);

    gl.LinkProgram(shader_program);
    gl.UseProgram(shader_program);

    // coordinate systems

    var model_matrix = math.Mat4.Translation(math.Vec3.Init(0, 0, -3));
    const model_location = gl.GetUniformLocation(shader_program, "model");
    gl.UniformMatrix4fv(model_location, 1, gl.TRUE, &model_matrix.data);

    const projection_matrix = math.Mat4.Perspective(std.math.degreesToRadians(45), windowWidth / widonwHeight, 0.1, 100);
    const projection_location = gl.GetUniformLocation(shader_program, "projection");
    gl.UniformMatrix4fv(projection_location, 1, gl.TRUE, &projection_matrix.data);

    // main loop

    gl.Enable(gl.DEPTH_TEST);
    gl.PolygonMode(gl.FRONT, gl.LINE);


    var frame_count: i64 = 0;
    var start_time = std.time.microTimestamp();

    const camera_speed = 0.05;

    var entities = try EntitiesStorage.init(allocator);
    defer entities.deinit();

    while (!glfw.windowShouldClose(window)) {

        // inputs

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
            continue;
        }

        const camera_direction = camera.Direction();

        if (glfw.getKey(window, glfw.KeyW) == glfw.Press)
            camera.position = camera.position.Add(camera_direction.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyS) == glfw.Press)
            camera.position = camera.position.Substract(camera_direction.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyA) == glfw.Press)
            camera.position = camera.position.Substract(math.Vec3.Cross(camera_direction, camera.up).Normalize().Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyD) == glfw.Press)
            camera.position = camera.position.Add(math.Vec3.Cross(camera_direction, camera.up).Normalize().Multiply(camera_speed));

        camera.update(shader_program);

        // rendering

        gl.ClearColor(0, 0, 255, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        frame_count +=1;
        const current_time = std.time.microTimestamp();
        const elasped_time = current_time - start_time;

        if (elasped_time >= 1_000_000) {
            const fps = @divTrunc(frame_count * 1_000_000, elasped_time);
            print("fps: {}\n", .{ fps });

            start_time = current_time;
            frame_count = 0;
        }

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}

var last_x: f64 = windowWidth / 2;
var last_y: f64 = widonwHeight / 2;
const mouse_sensitivity: f64 = 0.07;
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

    camera.rotation.y += @as(f32, @floatCast(x_offset));
    camera.rotation.x += @as(f32, @floatCast(y_offset));

    if (camera.rotation.x > 89.99)
        camera.rotation.x = 89.99;
    if (camera.rotation.x < -89.99)
        camera.rotation.x = -89.99;
}

pub fn createShaderFromFile(@"type": gl.@"enum", filePath: []const u8) !gl.uint  {
    const shader = gl.CreateShader(@"type");

    var file = try std.fs.openFileAbsolute(filePath, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(source);

    const newSource = try allocator.alloc(u8, @as(usize, @intCast(source.len + 1)));
    defer allocator.free(newSource);

    std.mem.copyForwards(u8, newSource, source);
    newSource[newSource.len - 1] = 0; // needs to be null terminated

    gl.ShaderSource(shader, 1, &[_][*]const u8 { newSource.ptr }, null);
    gl.CompileShader(shader);

    var compileStatus: gl.int = 0;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &compileStatus);

    if (compileStatus == gl.FALSE) {
        var logLength: gl.int = 0;
        gl.GetShaderiv(shader, gl.INFO_LOG_LENGTH, &logLength);

        const log =  try allocator.alloc(u8, @intCast(logLength));
        defer allocator.free(log);

        gl.GetShaderInfoLog(shader, logLength, &logLength, log.ptr);

        print(
            \\Failed to compile shader ({s})
            \\{s}
            ,
            .{ filePath, log }
        );
    }

    return shader;
}