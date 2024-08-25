// https://sites.google.com/site/letsmakeavoxelengine/home/landcape-creation

const std = @import("std");
const print = std.debug.print;
const allocator = std.heap.c_allocator;
const gl = @import("gl");
const glfw = @import("glfw");
const math = @import("math.zig");
const Camera = @import("camera.zig").Camera;
const EntitiesStorage = @import("ecs.zig").EntitiesStorage;
const VoxelDataStorage = @import("voxelDataStorage.zig").VoxelDataStorage;

const windowWidth = 800;
const widonwHeight = 640;

var camera = Camera {
    .fov = 75,
    .position = math.Vec3.Init(-5, 2, 0),
};

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.Resizable, 0);
    glfw.windowHint(glfw.Doublebuffer, 0);

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

    const worldSize = 2;
    const voxelCount = comptime std.math.pow(usize, worldSize, 3);
    var voxels = [_]bool { false } ** voxelCount;
    voxels[0] = true;
    voxels[worldSize] = true;
    voxels[std.math.pow(usize, worldSize, 2) - worldSize] = true;
    voxels[std.math.pow(usize, worldSize, 2) - 1] = true;

    const verticesPerEdge = worldSize + 1;
    const verticesLength = comptime std.math.pow(usize, verticesPerEdge, 2) * verticesPerEdge * 3;
    var voxelsVertices = [_]f32 { 0 } ** verticesLength;
    for (0..verticesPerEdge) |y| {
        for (0..verticesPerEdge) |z| {
            for (0..verticesPerEdge) |x| {
                const stride = std.math.pow(usize, verticesPerEdge, 2) * y + verticesPerEdge * z + x;
                var vertice: []f32 = voxelsVertices[stride..stride + 3];
                vertice[0] = @floatFromInt(x);
                vertice[1] = @as(f32, @floatFromInt(y)) * -1;
                vertice[2] = @floatFromInt(z);
                print("({d}, {d}, {d})", .{ vertice[0], vertice[1], vertice[2] });
            }
            print("\n", .{});
        }
        print("\n", .{});
    }

    const vertexIndices = [_]f32 { 0 } ** (voxelCount * 12 * 3); // 12 triangles per cube, 3 indices per triangle
    _ = vertexIndices;

    const vertices = [_]f32 {
        0.5,  0.5, 1.0,
        0.5, -0.5, 1.0,
        -0.5,  0.5, 1.0,
        0.5,  0.5, -3.0,
        0.5, -0.5, -3.0,
        -0.5,  0.5, -3.0
    };
    const indices = [_]u32 {
        3, 4, 5,
        0, 1, 2,
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

    // ray tracer

    var screenTex: gl.uint = 0;
    gl.CreateTextures(gl.TEXTURE_2D, 1, @ptrCast(&screenTex)); defer gl.DeleteTextures(1,  @ptrCast(&screenTex));

    gl.TextureStorage2D(screenTex, 1, gl.RGBA32F, windowWidth, widonwHeight);
    gl.BindImageTexture(0, screenTex, 0, gl.FALSE, 0, gl.WRITE_ONLY, gl.RGBA32F);

    const rayTracerShaderFilePath = try std.fs.cwd().realpathAlloc(allocator, "./src/rayTracer.comp"); defer allocator.free(rayTracerShaderFilePath);
    const rayTracerShader = try createShaderFromFile(gl.COMPUTE_SHADER, rayTracerShaderFilePath); defer gl.DeleteShader(rayTracerShader);

    const rayTracerProgram = gl.CreateProgram(); defer gl.DeleteProgram(rayTracerProgram);
    gl.AttachShader(rayTracerProgram, rayTracerShader);
    gl.LinkProgram(rayTracerProgram);
    gl.UseProgram(rayTracerProgram);

    const viewportVertices = [_] gl.float {
        -1, -1 , 0.0, 0.0, 0.0,
        -1,  1 , 0.0, 0.0, 1,
        1,  1 , 0.0, 1, 1,
        1, -1 , 0.0, 1, 0.0,
    };
    const viewportIndices = [_] gl.uint {
        0, 2, 1,
        0, 3, 2,
    };

    var VAO: gl.uint = 0;
    var VBO: gl.uint = 0;
    var EBO: gl.uint = 0;
    gl.CreateVertexArrays(1, @ptrCast(&VAO)); defer gl.DeleteVertexArrays(1, @ptrCast(&VAO));
    gl.CreateBuffers(1, @ptrCast(&VBO)); defer gl.DeleteBuffers(1, @ptrCast(&VBO));
    gl.CreateBuffers(1, @ptrCast(&EBO)); defer gl.DeleteBuffers(1, @ptrCast(&EBO));

    gl.NamedBufferData(VBO, @sizeOf(@TypeOf(viewportVertices)), &viewportVertices, gl.STATIC_DRAW);
    gl.NamedBufferData(EBO, @sizeOf(@TypeOf(viewportIndices)), &viewportIndices, gl.STATIC_DRAW);

    gl.EnableVertexArrayAttrib(VAO, 0);
    gl.VertexArrayAttribBinding(VAO, 0, 0);
    gl.VertexArrayAttribFormat(VAO, 0, 3, gl.FLOAT, gl.FALSE, 0);

    gl.EnableVertexArrayAttrib(VAO, 1);
    gl.VertexArrayAttribBinding(VAO, 1, 0);
	gl.VertexArrayAttribFormat(VAO, 1, 2, gl.FLOAT, gl.FALSE, @sizeOf(gl.float) * 3);

    gl.VertexArrayVertexBuffer(VAO, 0, VBO, 0, @sizeOf(gl.float) * 5);
	gl.VertexArrayElementBuffer(VAO, EBO);

    const viewportVertFilePath = try std.fs.cwd().realpathAlloc(allocator, "./src/viewport.vert"); defer allocator.free(viewportVertFilePath);
    const viewportVertShader = try createShaderFromFile(gl.VERTEX_SHADER, viewportVertFilePath); defer gl.DeleteShader(viewportVertShader);

    const viewportFragFilePath = try std.fs.cwd().realpathAlloc(allocator, "./src/viewport.frag"); defer allocator.free(viewportFragFilePath);
    const viewportFragShader = try createShaderFromFile(gl.FRAGMENT_SHADER, viewportFragFilePath); defer gl.DeleteShader(viewportFragShader);

    const viewportProgram = gl.CreateProgram(); defer gl.DeleteProgram(viewportProgram);
    gl.AttachShader(viewportProgram, viewportVertShader);
    gl.AttachShader(viewportProgram, viewportFragShader);
    gl.LinkProgram(viewportProgram);

    // coordinate systems

    var model_matrix = math.Mat4.Translation(math.Vec3.Init(0, 0, -3));
    const model_location = gl.GetUniformLocation(shader_program, "model");
    gl.UniformMatrix4fv(model_location, 1, gl.TRUE, &model_matrix.data);

    const projection_matrix = math.Mat4.Perspective(std.math.degreesToRadians(45), windowWidth / widonwHeight, 0.1, 100);
    const projection_location = gl.GetUniformLocation(shader_program, "projection");
    gl.UniformMatrix4fv(projection_location, 1, gl.TRUE, &projection_matrix.data);

    // main loop

    // gl.Enable(gl.DEPTH_TEST);
    // gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    // gl.Enable(gl.BLEND);
    // gl.Enable(gl.CULL_FACE);
    // gl.CullFace(gl.BACK);
    // gl.Viewport(0, 0, windowWidth, widonwHeight);
    // gl.FrontFace(gl.CW);

    var frame_count: i64 = 0;
    var start_time = std.time.microTimestamp();

    const camera_speed = 0.1;

    var entities = try EntitiesStorage.init(allocator);
    defer entities.deinit();

    // send array to gpu

    const worldSize2: u32 = 1024;
    // TODO: packed type in u32, or else memory will be bust
    var voxels2: [worldSize2]u32 =  .{ 0 } ** worldSize2;
    // normally we'd want to packed the bools in a 32 bits type
    // glsl bool take 32 bits ...
    voxels2[0] = 1;
    voxels2[4] = 1;
    voxels2[5] = 1;
    voxels2[6] = 1;
    voxels2[150] = 1;
    voxels2[152] = 1;
    voxels2[153] = 1;
    voxels2[154] = 1;
    voxels2[155] = 1;
    voxels2[158] = 1;
    voxels2[299] = 1;

    var SSBO: gl.uint = 0;

    gl.GenBuffers(1, @ptrCast(&SSBO)); defer gl.DeleteBuffers(1, @ptrCast(&SSBO));
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, SSBO);
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, @sizeOf(@TypeOf(voxels2)), &voxels2, gl.DYNAMIC_DRAW);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, SSBO);

    var voxelStorage = try VoxelDataStorage.init(&allocator); defer voxelStorage.deinit();
    try voxelStorage.setData(1, &math.Vec3.Init(0, 0, 0));
    try voxelStorage.setData(1, &math.Vec3.Init(0, 0, 1));
    try voxelStorage.setData(1, &math.Vec3.Init(0, 1, 0));

    var SSBO2: gl.uint = 0;

    gl.GenBuffers(1, @ptrCast(&SSBO2)); defer gl.DeleteBuffers(1, @ptrCast(&SSBO2));
    gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, SSBO2);
    gl.BufferData(gl.SHADER_STORAGE_BUFFER, @as(isize, @intCast(@sizeOf(@TypeOf(voxelStorage.voxelData[0])) * voxelStorage.voxelData.len)), voxelStorage.voxelData.ptr, gl.DYNAMIC_DRAW);
    gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, SSBO2);

    while (!glfw.windowShouldClose(window)) {

        // inputs

        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
            continue;
        }

        const cameraDirection = camera.Direction();

        if (glfw.getKey(window, glfw.KeyW) == glfw.Press)
            camera.position = camera.position.Add(cameraDirection.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyS) == glfw.Press)
            camera.position = camera.position.substract(cameraDirection.Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyA) == glfw.Press)
            camera.position = camera.position.substract(math.Vec3.Cross(cameraDirection, camera.up).Normalize().Multiply(camera_speed));
        if (glfw.getKey(window, glfw.KeyD) == glfw.Press)
            camera.position = camera.position.Add(math.Vec3.Cross(cameraDirection, camera.up).Normalize().Multiply(camera_speed));

        gl.UseProgram(rayTracerProgram);
        gl.Uniform3fv(gl.GetUniformLocation(rayTracerProgram, "cameraPosition"), 1, camera.position.cPtr());
        gl.Uniform3fv(gl.GetUniformLocation(rayTracerProgram, "cameraDirection"), 1, cameraDirection.cPtr());
        gl.Uniform1f(gl.GetUniformLocation(rayTracerProgram, "cameraFov"), camera.fov);
        gl.DispatchCompute(@ceil(@as(f32, @floatCast(windowWidth / 8))), @ceil(@as(f32, @floatCast(widonwHeight / 4))), 1);
        gl.MemoryBarrier(gl.ALL_BARRIER_BITS);
        
        gl.UseProgram(viewportProgram);
        gl.BindTextureUnit(0, screenTex);
        gl.Uniform1i(gl.GetUniformLocation(viewportProgram, "viewport"), 0); // TODO: what is this ?
        gl.BindVertexArray(VAO);
        gl.DrawElements(gl.TRIANGLES, viewportIndices.len, gl.UNSIGNED_INT, 0);

        frame_count +=1;
        const current_time = std.time.microTimestamp();
        const elasped_time = current_time - start_time;

        if (elasped_time >= 1_000_000) {
            const fps = @divTrunc(frame_count * 1_000_000, elasped_time);
            print("fps: {}\n", .{ fps });

            start_time = current_time;
            frame_count = 0;
        }

        gl.Flush();
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