const Vec3 = @import("math.zig").Vec3;
const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;

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
    data: DataUnion,
    _: u1 = 0, // padding for alignment
    hasData: bool,
    isLeaf: bool,

    const This = @This();

    pub fn dataNode(center: Vec3, data: bool) OctreeNode {
        return OctreeNode {
            .center = center,
            .isLeaf = true,
            .hasData = true,
            .data = DataUnion { .data  = data }
        };
    }

    pub fn setAsLeafWithData(this: *This, data: bool) void {
        this.data.data = data;
        this.isLeaf = true;
        this.hasData = true;
    }

    pub fn setAsLeafWithoutData(this: *This) void {
        this.isLeaf = true;
        this.hasData = false;
    }

    pub fn setAsParent(this: *This, childrenIndex: u13) void {
        this.data.childrenIndex  = childrenIndex;
        this.isLeaf = false;
        this.hasData = false;
    }

    const DataUnion = packed union {
        // max OctreeNode count for a max depth of D
        // [leaf], [parent][leaf][leaf][leaf][leaf][leaf][leaf][leaf][leaf], etc...
        // (1/7) * (8^(D + 1) - 1)
        childrenIndex: u13,
        data: bool,
    };
};

// TODO: rename to PointRegionOctree?
pub const Octree = struct {
    nodes: []OctreeNode,
    allocator: std.mem.Allocator,

    const This = @This();

    pub fn init(allocator: std.mem.Allocator, center: Vec3) !*This {

        const octree = try allocator.create(This);
        octree.allocator = allocator;
        octree.nodes = try allocator.alloc(OctreeNode, 1);
        octree.nodes[0] = OctreeNode.dataNode(center, false);
        return octree;
    }

    pub fn deinit(this: *This) void {
        this.allocator.free(this.nodes);
        this.allocator.destroy(this);
    }

    pub fn setNode(this: *This, position: *const Vec3, data: bool) !void {
        var nodeIndex: u13 = 0; // same as OctreeNode.data.childrenIndex
        var node = this.nodes[nodeIndex];
        while (true) {

            if (node.isLeaf) {
                
                if (!node.hasData)
                    node.setAsLeafWithData(data);

                if (node.data.data == data)
                    return;

                const newSize = this.nodes.len + 8;
                if (!this.allocator.resize(this.nodes, newSize)) {
                    const newNodes = try this.allocator.alloc(OctreeNode, newSize);
                    @memcpy(newNodes[0..this.nodes.len], this.nodes);
                    this.allocator.free(this.nodes);
                    this.nodes = newNodes;

                    node = this.nodes[nodeIndex];
                }
                this.nodes.len = newSize;

                const halfSize = node.center.divide(2); // TODO: fix for center(0, 0, 0)
                for (this.nodes[this.nodes.len - 8..], 0..) |*newNode, i| {
                    newNode.center = node.center.substract(Vec3.Init(
                        halfSize.x * @as(f32, @floatFromInt(-(@as(i4, @intCast(i)) >> 2 & 1) | 1)),
                        halfSize.y * @as(f32, @floatFromInt(-(@as(i4, @intCast(i)) >> 1 & 1) | 1)),
                        halfSize.z * @as(f32, @floatFromInt(-(@as(i4, @intCast(i)) & 1) | 1))
                    ));
                    newNode.setAsLeafWithoutData();
                }

                const childrenIndex: u13 = @intCast(this.nodes.len - 8);
                var firstChildNode = this.nodes[childrenIndex];
                firstChildNode.setAsLeafWithData(node.data.data);

                var secondChildNode = this.nodes[childrenIndex + 1];
                secondChildNode.setAsLeafWithData(data);

                node.setAsParent(childrenIndex);

                return;
            }
            
            const r = node.center.substract(position.*);
            const xSign: u3 = @intFromBool(std.math.signbit(r.x));
            const ySign: u3 = @intFromBool(std.math.signbit(r.y));
            const zSign: u3 = @intFromBool(std.math.signbit(r.z));
            const offset = xSign << 2 | ySign << 1 | zSign;

            nodeIndex = node.data.childrenIndex + offset;
        }
    }
};

test "expect gg" {
    const octree = try Octree.init(std.testing.allocator, Vec3.Init(5, 5, 5)); defer octree.deinit();
    try octree.setNode(&Vec3.Init(-0.000001, 0.0001, 0), true);
    try octree.setNode(&Vec3.Init(6, 9, -5), true);

    try octree.setNode(&Vec3.Init(0, 0, 0), true);
    try octree.setNode(&Vec3.Init(0, 0, 0), true);
    try octree.setNode(&Vec3.Init(0, 0, 0), true);
}