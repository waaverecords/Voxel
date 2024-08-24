const Vec3 = @import("math.zig").Vec3;
const Allocator = @import("std").mem.Allocator;

pub fn VoxelDataStorage(comptime VoxelDataType: type) type {
    return struct {
        allocator: Allocator,

        // a bit's index (right to left) represents a Morton encoded coordinate
        // an active bit means the voxel at its Morton coordinate has a value
        // an active bit's index (right to left) (index for active bits only) represents the index of its voxel data (.voxelData)
        header: u64,

        voxelData: []VoxelDataType,

        const This = @This();

        pub fn init(allocator: Allocator) !*This {
            const storage = try allocator.create(This);
            storage.allocator = allocator;
            storage.voxelData = try allocator.alloc(VoxelDataType, 0);
            return storage;
        }

        pub fn deinit(this: *This) void {
            this.allocator.free(this.voxelData);
            this.allocator.destroy(this);
        }

        pub fn setDataAtPosition(this: *This, data: VoxelDataType, position: *const Vec3) !void {
            // TODO: assert position
            _ = position;

            const morton = 5; // TODO: get morton value from position

            this.header |= 1 << morton;

            const mask = 1  << (morton + 1) - 1;
            const bitCount = @popCount(this.header & mask);
            const dataIndex = if (bitCount > 0) bitCount -  1 else 0;

            // TODO: handle when position has data already
            // TODO: extract to grow function?
            const newSize = this.voxelData.len + 1;
            const newVoxelData = try this.allocator.alloc(VoxelDataType, newSize);
            @memcpy(newVoxelData[0..dataIndex], this.voxelData[0..dataIndex]);
            @memcpy(newVoxelData[dataIndex + 1..], this.voxelData[dataIndex..]);
            this.allocator.free(this.voxelData);
            this.voxelData = newVoxelData;
            this.voxelData.len = newSize;

            this.voxelData[dataIndex] = data;
        }
    };
}

test VoxelDataStorage {
    const testing = @import("std").testing;
    const allocator = testing.allocator;
    const expect = testing.expect;

    var storage = try VoxelDataStorage(u8).init(allocator); defer storage.deinit();

    try storage.setDataAtPosition(8, &Vec3.Init(0, 0, 0));
    try expect(storage.voxelData[0] == 8);

    try storage.setDataAtPosition(10, &Vec3.Init(0, 0, 0));
    try expect(storage.voxelData[0] == 10);
    try expect(storage.voxelData[1] == 8);

    try storage.setDataAtPosition(12, &Vec3.Init(0, 0, 0));
    try expect(storage.voxelData[0] == 12);
    try expect(storage.voxelData[1] == 10);
    try expect(storage.voxelData[2] == 8);
}