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
};

fn part1By2(operand: u32) u6 {
    var x: u6 = @as(u2, @truncate(operand));
    x = (x | (x << 4)) & 0b100011;
    x = (x | (x << 2)) & 0b100100;
    return x;
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