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

        pub fn setData(this: *This, data: VoxelDataType, position: *const Vec3) !void {
            // TODO: assert position
            _ = position;

            const morton = 5; // TODO: get morton value from position

            const hasDataMask = 1 << morton;

            const newHeader = this.header | hasDataMask;

            const mask = 1  << (morton + 1) - 1;
            const bitCount = @popCount(newHeader & mask);
            const dataIndex = if (bitCount > 0) bitCount -  1 else 0;

            const hasData = this.header & hasDataMask > 0;
            if (hasData) {
                this.voxelData[dataIndex] = data;
                return;
            }
            
            try this.insertData(data, dataIndex);
            this.header = newHeader;
        }

        fn insertData(this: *This, data: VoxelDataType, index: usize) !void {
            const newSize = this.voxelData.len + 1;
            const newVoxelData = try this.allocator.alloc(VoxelDataType, newSize);
            @memcpy(newVoxelData[0..index], this.voxelData[0..index]);
            @memcpy(newVoxelData[index + 1..], this.voxelData[index..]);
            this.allocator.free(this.voxelData);
            this.voxelData = newVoxelData;
            this.voxelData.len = newSize;

            this.voxelData[index] = data;
        }
    };
}

test "insert data" {
    const testing = @import("std").testing;
    const allocator = testing.allocator;

    var storage = try VoxelDataStorage(u8).init(allocator); defer storage.deinit();

    try storage.insertData(0, 0);
    try testing.expectEqualSlices(u8, &[_]u8 { 0 }, storage.voxelData);

    try storage.insertData(1, 0);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 0 }, storage.voxelData);

    try storage.insertData(2, 2);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 0, 2 }, storage.voxelData);

    try storage.insertData(3, 1);
    try testing.expectEqualSlices(u8, &[_]u8 { 1, 3, 0, 2 }, storage.voxelData);
}