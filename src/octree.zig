const Vec3 = @import("math.zig").Vec3;
const std = @import("std");

// pub fn from3DCubeXYZ(
//     comptime ValueType: type,
//     comptime cubeSize: usize,
//     data: *const [cubeSize][cubeSize][cubeSize] ValueType
// ) OctreeNode(ValueType) {
//     // TODO: check if needed, if |closest| is 0, then center is only farthest / 2
//     const closest  = Vec3{};
//     const farthest = Vec3.Init(data.len - 1, data[0].len - 1, data[0][0].len - 1);
//     const center = farthest.substract(closest).divide(2).Add(closest);
//     _ = center;

//     return OctreeNode(ValueType){};
// }

// pub fn OctreeNode(comptime ValueType: type) type {
//     return extern struct {
//         value: ValueType = undefined,
//         children: [8]OctreeNode(ValueType) = undefined,
//     };
// }

pub const OctreeNode = packed struct(u16) {
    isLeaf: bool,
    data: DataUnion,
    _: u3 = 0, // padding for alignment

    pub fn dataNode(data: bool) OctreeNode {
        return OctreeNode {
            .isLeaf = true,
            .data = DataUnion { .data  = data }
        };
    }

    const DataUnion = packed union {
        childrenIndex: u12,
        data: bool,
    };
};

pub const Octree = struct {
    nodes: []OctreeNode,
    allocator: std.mem.Allocator,

    const This = @This();

    pub fn init(allocator: std.mem.Allocator) !*This {
        const octree = try allocator.create(This);
        octree.allocator = allocator;
        octree.nodes = try allocator.alloc(OctreeNode, 0);
        return octree;
    }

    pub fn deinit(this: *This) void {
        this.allocator.free(this.nodes);
        this.allocator.destroy(this);
    }
};

test "test" {
    const octree = try Octree.init(std.heap.c_allocator); defer octree.deinit();
}