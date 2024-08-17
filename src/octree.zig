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

pub const OctreeNode = packed struct(u112) {
    center: Vec3,
    isLeaf: bool,
    data: DataUnion,
    _: u2 = 0, // padding for alignment

    pub fn dataNode(data: bool) OctreeNode {
        return OctreeNode {
            .isLeaf = true,
            .data = DataUnion { .data  = data }
        };
    }

    const DataUnion = packed union {
        // max OctreeNode count for a max depth of D
        // [leaf], [parent][leaf][leaf][leaf][leaf][leaf][leaf][leaf][leaf], etc...
        // (1/7) * (8^(D + 1) - 1)
        childrenIndex: u13,
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
    const print = std.debug.print;

    const octree = try Octree.init(std.heap.c_allocator); defer octree.deinit();
    
    const x: u32 = 100;
    const y: u32 = 0;
    const z: u32 = 0;
    const level = 0;
    print("base ({d}, {d}, {d}, {d})\n", .{ x, y, z, level });

    const xAtLevel: u1 = @intCast(x >> level & 1);
    const yAtLevel: u1 = @intCast(y >> level & 1);
    const zAtLevel: u1 = @intCast(z >> level & 1);
    print("atLevel ({d}, {d}, {d}, {d})\n", .{ xAtLevel, yAtLevel, zAtLevel, level });

    print("offset ({d}, {d})\n", .{
        (@as(u3, @intCast(xAtLevel)) << 2) | (@as(u3, @intCast(yAtLevel)) << 1) | @as(u3, @intCast(zAtLevel)),
        level
    });
}