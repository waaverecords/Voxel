const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Vec3 = @import("math.zig").Vec3;

const headerByteCount = 8;

pub const VoxelDataStorage = struct {
    allocator: *const Allocator,

    // a bit's index (right to left) represents a Morton encoded coordinate
    // an active bit means the voxel at its Morton coordinate has a value
    // an active bit's index (right to left) (index for active bits only) represents the index of its voxel data (.voxelData)
    header: *u64,

    voxelData: []u8,

    const This = @This();

    pub fn init(allocator: *const Allocator) !*This {
        const storage = try allocator.create(This);
        storage.allocator = allocator;
        storage.voxelData = try allocator.alloc(u8, headerByteCount);
        @memset(storage.voxelData, 0);
        storage.header = @as(*u64, @alignCast(@ptrCast(storage.voxelData.ptr)));
        return storage;
    }

    pub fn deinit(this: *This) void {
        this.header = undefined;
        this.allocator.free(this.voxelData);
        this.allocator.destroy(this);
    }

    pub fn setData(this: *This, data: u8, position: *const Vec3) !void {
        assert(0 <= position.x and position.x < 4);
        assert(0 <= position.y and position.y < 4);
        assert(0 <= position.z and position.z < 4);

        const morton: u6 = 
            part1By2(@as(u6, @intFromFloat(position.x))) |
            part1By2(@as(u6, @intFromFloat(position.y))) >> 1 |
            part1By2(@as(u6, @intFromFloat(position.z))) >> 2;
            
        const hasDataMask = @as(u64, 1) << morton;

        const newHeader = this.header.* | hasDataMask;
        
        const mask = if (morton == 63) std.math.maxInt(u64) else (@as(u64, 1) << (morton + 1)) - 1;
        const bitCount = @popCount(newHeader & mask);
        const dataIndex = headerByteCount + if (bitCount > 0) bitCount - 1 else 0;
        
        const hasData = this.header.* & hasDataMask > 0;
        if (hasData) {
            this.voxelData[dataIndex] = data;
            return;
        }
        
        try this.insertData(data, dataIndex);
        this.header.* = newHeader;
    }

    fn insertData(this: *This, data: u8, index: usize) !void {
        const newSize = this.voxelData.len + 1;
        const newVoxelData = try this.allocator.alloc(u8, newSize);
        @memcpy(newVoxelData[0..index], this.voxelData[0..index]);
        @memcpy(newVoxelData[index + 1..], this.voxelData[index..]);
        this.allocator.free(this.voxelData);
        this.voxelData = newVoxelData;
        this.voxelData.len = newVoxelData.len;

        this.header = @as(*u64, @alignCast(@ptrCast(this.voxelData.ptr)));

        this.voxelData[index] = data;
    }

    pub fn getIntersectionsWithRay(this: *This, allocator: Allocator, rayStart: Vec3, rayEnd: Vec3) ![]Vec3 {
        _ = this;
        // TODO: if ray outside of grid, find intersection point with grid and

        var currentVoxel = Vec3.Init(
            @floor(rayStart.x),
            @floor(rayStart.y),
            @floor(rayStart.z)
        );
        const endVoxel = Vec3.Init(
            @floor(rayEnd.x), 
            @floor(rayEnd.y), 
            @floor(rayEnd.z)
        );

        const ray = rayEnd.subtract(rayStart);
        const rayDirection = ray.Normalize();
        
        const step = Vec3.Init(
            std.math.sign(ray.x),
            std.math.sign(ray.y),
            std.math.sign(ray.z)
        );
        const nextVoxelBoundary = Vec3.Init(
            currentVoxel.x + if (step.x > 0) step.x else 0,
            currentVoxel.y + if (step.y > 0) step.y else 0,
            currentVoxel.z + if (step.z > 0) step.z else 0    
        );
        var tMax = Vec3.Init(
            if (rayDirection.x != 0) (nextVoxelBoundary.x - rayStart.x) / rayDirection.x else std.math.floatMax(f32),
            if (rayDirection.y != 0) (nextVoxelBoundary.y - rayStart.y) / rayDirection.y else std.math.floatMax(f32),
            if (rayDirection.z != 0) (nextVoxelBoundary.z - rayStart.z) / rayDirection.z else std.math.floatMax(f32)
        );
        const tDelta = Vec3.Init(
            if (rayDirection.x != 0) @abs(1 / rayDirection.x) else std.math.floatMax(f32),
            if (rayDirection.y != 0) @abs(1 / rayDirection.y) else std.math.floatMax(f32),
            if (rayDirection.z != 0) @abs(1 / rayDirection.z) else std.math.floatMax(f32)
        );

        var voxelHits = std.ArrayList(Vec3).init(allocator);
        try voxelHits.append(currentVoxel);
        
        while (!std.meta.eql(endVoxel, currentVoxel)) {
            const minAxis: usize = if (tMax.x <= tMax.y and tMax.x <= tMax.z) 0 else if (tMax.y <= tMax.x and tMax.y <= tMax.z) 1 else 2;
            const minTMax = tMax.at(minAxis).*;
            
            inline for (0..3) |i| {
                if (tMax.at(i).* == minTMax) {
                    currentVoxel.at(i).* += step.at(i).*;
                    tMax.at(i).* += tDelta.at(i).*;
                }
            }
            // TODO: only append if voxel not empty
            try voxelHits.append(currentVoxel);
        }

        return voxelHits.toOwnedSlice();
    }
};

fn part1By2(operand: u32) u6 {
    var x: u6 = @as(u2, @truncate(operand));
    x = (x | (x << 4)) & 0b100011;
    x = (x | (x << 2)) & 0b100100;
    return x;
}

test "getIntersectionsWithRay" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var storage = try VoxelDataStorage.init(&allocator); defer storage.deinit();

    const hits = try storage.getIntersectionsWithRay(allocator, Vec3.Init(3.5, 3.5, 3.5), Vec3.Init(0.5, 0.5, 0.5)); defer allocator.free(hits);
    try testing.expectEqual(4, hits.len);
    try testing.expectEqual(Vec3.Init(3, 3, 3), hits[0]);
    try testing.expectEqual(Vec3.Init(2, 2, 2), hits[1]);
    try testing.expectEqual(Vec3.Init(1, 1, 1), hits[2]);
    try testing.expectEqual(Vec3.Init(0, 0, 0), hits[3]);

    const hits2 = try storage.getIntersectionsWithRay(allocator, Vec3.Init(0, 0, 0), Vec3.Init(2, 0, 0)); defer allocator.free(hits2);
    try testing.expectEqual(3, hits2.len);
    try testing.expectEqual(Vec3.Init(0, 0, 0), hits2[0]);
    try testing.expectEqual(Vec3.Init(1, 0, 0), hits2[1]);
    try testing.expectEqual(Vec3.Init(2, 0, 0), hits2[2]);

    const hits3 = try storage.getIntersectionsWithRay(allocator, Vec3.Init(0.25, 0, 0), Vec3.Init(3.5, 3.25, 0)); defer allocator.free(hits3);
    try testing.expectEqual(7, hits3.len);
    try testing.expectEqual(Vec3.Init(0, 0, 0), hits3[0]);
    try testing.expectEqual(Vec3.Init(1, 0, 0), hits3[1]);
    try testing.expectEqual(Vec3.Init(1, 1, 0), hits3[2]);
    try testing.expectEqual(Vec3.Init(2, 1, 0), hits3[3]);
    try testing.expectEqual(Vec3.Init(2, 2, 0), hits3[4]);
    try testing.expectEqual(Vec3.Init(3, 2, 0), hits3[5]);
    try testing.expectEqual(Vec3.Init(3, 3, 0), hits3[6]);
}

test "insertData" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var storage = try VoxelDataStorage.init(&allocator); defer storage.deinit();

    try storage.insertData(0, headerByteCount);
    try testing.expectEqualSlices(u8, &[_]u8 { 0 }, storage.voxelData[8..]);

    try storage.insertData(1, headerByteCount);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 0 }, storage.voxelData[8..]);

    try storage.insertData(2, headerByteCount + 2);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 0, 2 }, storage.voxelData[8..]);

    try storage.insertData(3, headerByteCount + 1);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 3, 0, 2 }, storage.voxelData[8..]);
}

test "setData" {
    const testing = std.testing;
    const allocator = testing.allocator;
    
    var storage = try VoxelDataStorage.init(&allocator); defer storage.deinit();

    try storage.setData(0, &Vec3{});
    try testing.expect(storage.header.* == 0b1);
    try testing.expectEqualSlices(u8, &[_]u8 { 0 }, storage.voxelData[8..]);

    try storage.setData(1, &Vec3.Init(3, 3, 3));
    try testing.expect(storage.header.* == 0b1000000000000000000000000000000000000000000000000000000000000001);
    try testing.expectEqualSlices(u8, &[_]u8 { 0, 1 }, storage.voxelData[8..]);

    try storage.setData(2, &Vec3.Init(3, 3, 2));
    try testing.expect(storage.header.* == 0b1100000000000000000000000000000000000000000000000000000000000001);
    try testing.expectEqualSlices(u8, &[_]u8 { 0, 2, 1 }, storage.voxelData[8..]);

    try storage.setData(3, &Vec3.Init(3, 3, 2));
    try testing.expect(storage.header.* == 0b1100000000000000000000000000000000000000000000000000000000000001);
    try testing.expectEqualSlices(u8, &[_]u8 { 0, 3, 1 }, storage.voxelData[8..]);
}