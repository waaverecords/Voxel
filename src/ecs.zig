const std = @import("std");
const Allocator = @import("std").mem.Allocator;

// https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/

pub const void_archetype_hash = std.math.maxInt(u64);

pub const EntitiesStorage = struct {
    allocator: Allocator,

    archetype_storages: std.AutoArrayHashMapUnmanaged(u64, ArchetypeStorage) = .{},

    pub fn init(allocator: Allocator) !EntitiesStorage {
        var storage = EntitiesStorage{ .allocator = allocator };
        try storage.archetype_storages.put(
            allocator, 
            void_archetype_hash, 
            ArchetypeStorage {
                .allocator = allocator,
                .hash = void_archetype_hash
            }
        );
        return storage;
    }

    pub fn deinit(self: *EntitiesStorage) void {
        var i = self.archetype_storages.iterator();
        while (i.next()) |storage|
            storage.value_ptr.deinit();
        self.archetype_storages.deinit(self.allocator);
    }
};

pub const ArchetypeStorage = struct {
    allocator: Allocator,

    hash: u64,
    component_storages: std.StringArrayHashMapUnmanaged(OpaqueComponentStorage) = .{},

    pub fn deinit(self: *ArchetypeStorage) void {
        for (self.component_storages.values()) |storage|
            storage.deinit(storage.component_storage, self.allocator);
        self.component_storages.deinit(self.allocator);
    }
};

pub fn ComponentStorage(comptime Component: type) type {
    return struct {
        components: std.ArrayListUnmanaged(Component) = .{},

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.components.deinit(allocator);
        }
    };
}

pub const OpaqueComponentStorage = struct {
    component_storage: *anyopaque,
    deinit: *const fn (self: *anyopaque, allocator: Allocator) void
};