const builtin = @import("builtin");
const std = @import("std");
const meta = std.meta;

pub fn VecFns(comptime Self: type) type {
    comptime var N = @typeInfo(Self).Struct.fields.len;
    comptime var T = @typeInfo(Self).Struct.fields[0].field_type;
    comptime {
        if (@typeInfo(T) == .Array) {
            if (N > 1) {
                @compileError("Generic Vec can only have 1 field.");
            }
            N = @typeInfo(T).Array.len;
            T = @typeInfo(T).Array.child;
        } else {
            inline for (@typeInfo(Self).Struct.fields) |f| {
                if (T != f.field_type) {
                    @compileError("All fields of a Vec must be of the same type");
                }
            }
        }
    }
    return struct {
        pub usingnamespace VecFloat(Self, T);
        pub usingnamespace VecToArray(Self, N, T);

        pub const T = T;
        pub const N = N;

        pub fn map(self: Self, comptime f: anytype, args: anytype) Self {
            var r: getArrayType() = undefined;
            var v1 = self.toArray();
            comptime var opts: std.builtin.CallOptions = .{};

            comptime var i = 0;
            inline while (i < N) : (i += 1) {
                r[i] = @call(opts, f, .{v1[i]} ++ args);
            }
            return Self.fromArray(r);
        }
        pub fn apply(self: Self, comptime f: anytype) Self {
            return self.map(f, .{});
        }
        pub fn map2(a: anytype, b: anytype, comptime f: anytype, args: anytype) Self {
            var r: getArrayType() = undefined;
            var v1 = a.toArray();
            comptime var other_info = @typeInfo(@TypeOf(b));
            comptime var isStruct = other_info == .Struct;
            comptime var opts: std.builtin.CallOptions = .{};
            if (isStruct) {
                var v2 = b.toArray();
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = @call(opts, f, .{ v1[i], v2[i] } ++ args);
                }
            } else {
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = @call(opts, f, .{ v1[i], b } ++ args);
                }
            }
            return Self.fromArray(r);
        }
        pub fn reduce(self: Self, comptime f: anytype, args: anytype) T {
            comptime var opts: std.builtin.CallOptions = .{};
            var v1 = self.toArray();
            var r: T = v1[0];
            comptime var i = 1;
            inline while (i < N) : (i += 1) {
                r = @call(opts, f, .{ r, v1[i] } ++ args);
            }

            return r;
        }
        pub fn add(self: Self, other: anytype) Self {
            return map2(self, other, _add, .{});
        }
        pub fn mul(self: Self, other: anytype) Self {
            return map2(self, other, _mul, .{});
        }
        pub fn sub(self: Self, other: anytype) Self {
            return map2(self, other, _sub, .{});
        }
        pub fn lerp(self: Self, other: anytype, a: T) Self {
            return map2(self, other, _lerp, .{a});
        }
        pub fn sum(self: Self) T {
            return self.reduce(_add, .{});
        }
        pub fn divExact(self: Self, other: anytype) Self {
            return map2(self, other, _divExact, .{});
        }
        pub fn divFloor(self: Self, other: anytype) Self {
            return map2(self, other, _divFloor, .{});
        }
        pub fn div(self: Self, other: anytype) Self {
            return map2(self, other, _div, .{});
        }
        pub fn max(self: Self, other: anytype) Self {
            return map2(self, other, _max, .{});
        }
        pub fn min(self: Self, other: anytype) Self {
            return map2(self, other, _min, .{});
        }
        pub fn eq(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _eq, .{}).reduce(_and, .{});
        }
        pub fn into(self: Self, comptime VType: type) VType {
            if (comptime N != VType.N) {
                @compileError("Can't convert into type. Both vectors must have the same dimension.");
            }
            if (comptime T == VType.T and @sizeOf(Self) == @sizeOf(VType)) {
                return @bitCast(VType, self);
            }

            var v = self.toArray();
            var r: VType.getArrayType() = undefined;
            comptime var i = 0;
            inline while (i < N) : (i += 1) {
                if (comptime T != VType.T) {
                    switch (@typeInfo(T)) {
                        .Float => {
                            switch (@typeInfo(VType.T)) {
                                .Float => {
                                    r[i] = @floatCast(VType.T, v[i]);
                                },
                                .Int => {
                                    r[i] = @floatToInt(VType.T, v[i]);
                                },
                                else => unreachable,
                            }
                        },
                        .Int => {
                            switch (@typeInfo(VType.T)) {
                                .Float => {
                                    r[i] = @intToFloat(VType.T, v[i]);
                                },
                                .Int => {
                                    r[i] = @intCast(VType.T, v[i]);
                                },
                                else => unreachable,
                            }
                        },
                        else => unreachable,
                    }
                } else {
                    r[i] = v[i];
                }
            }
            return VType.fromArray(r);
        }
        pub fn join(self: Self, other: Self) [2 * N]T {
            var array: [2 * N]T = undefined;
            var v1 = self.toArray();
            var v2 = other.toArray();
            for (v1) |v, i| {
                array[i] = v;
            }
            for (v2) |v, i| {
                array[N + i] = v;
            }
            return array;
        }
        pub fn zero() Self {
            return std.mem.zeroes(Self);
        }
        pub fn all(n: anytype) Self {
            var r: getArrayType() = undefined;
            inline for (r) |*e| {
                e.* = n;
            }
            return Self.fromArray(r);
        }
        pub fn getArrayType() type {
            return [N]T;
        }
    };
}

pub fn GenericVec(comptime N: comptime_int, comptime T: type) type {
    return struct {
        usingnamespace VecFns(@This());
        data: [N]T,
    };
}

fn VecToArray(comptime Self: type, comptime N: comptime_int, comptime T: type) type {
    if (@typeInfo(Self).Struct.fields[0].field_type == [N]T) {
        return struct {
            pub fn toArray(self: Self) [N]T {
                return @field(self, @typeInfo(Self).Struct.fields[0].name);
            }
            pub fn fromArray(array: [N]T) Self {
                var r: Self = undefined;
                @field(r, @typeInfo(Self).Struct.fields[0].name) = array;
                return r;
            }
        };
    } else {
        return struct {
            pub fn toArray(self: Self) [N]T {
                if (@sizeOf([N]T) == @sizeOf(Self)) {
                    return @bitCast([N]T, self);
                } else {
                    var r: [N]T = undefined;
                    comptime var i = 0;
                    inline while (i < N) : (i += 1) {
                        r[i] = @field(self, @typeInfo(Self).Struct.fields[i].name);
                    }
                    return r;
                }
            }
            pub fn fromArray(array: [N]T) Self {
                var r: Self = undefined;
                inline for (meta.fields(Self)) |f, i| {
                    const name = f.name;
                    @field(r, name) = array[i];
                }
                return r;
            }
        };
    }
}

fn VecFloat(comptime Self: type, comptime T: type) type {
    if (comptime isFloat(T)) {
        return struct {
            pub fn len(self: Self) T {
                return std.math.sqrt(self.mul(self).sum());
            }
            pub fn distance(self: Self, other: anytype) T {
                var s = self.sub(other);
                return std.math.sqrt(s.mul(s).sum());
            }
            pub fn norm(self: Self) Self {
                var l = self.len();
                if (l > 0 or l < 0) {
                    return self.div(l);
                } else {
                    return Self.zero();
                }
            }
        };
    } else {
        return struct {};
    }
}

fn isFloat(comptime t: type) bool {
    return switch (@typeInfo(t)) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
}
inline fn _add(a: anytype, b: anytype) @TypeOf(a) {
    return a + b;
}
inline fn _mul(a: anytype, b: anytype) @TypeOf(a) {
    return a * b;
}
inline fn _sub(a: anytype, b: anytype) @TypeOf(a) {
    return a - b;
}
inline fn _lerp(a: anytype, b: anytype, c: anytype) @TypeOf(a) {
    return a * c + b * (1 - c);
}
inline fn _divExact(a: anytype, b: anytype) @TypeOf(a) {
    return @divExact(a, b);
}
inline fn _divFloor(a: anytype, b: anytype) @TypeOf(a) {
    return @divFloor(a, b);
}
inline fn _div(a: anytype, b: anytype) @TypeOf(a) {
    return a / b;
}
inline fn _max(a: anytype, b: anytype) @TypeOf(a) {
    return if (a > b) a else b;
}
inline fn _min(a: anytype, b: anytype) @TypeOf(a) {
    return if (a < b) a else b;
}
inline fn _eq(a: anytype, b: anytype) bool {
    return a == b;
}
inline fn _and(a: bool, b: bool) bool {
    return a and b;
}

test "VecFns.eq" {
    const V = struct {
        pub usingnamespace VecFns(@This());
        x: f32 = 0.5,
        y: f32 = 0.5,
    };
    
    var v: V = .{};
    try std.testing.expect(v.eq(0) == false);
    try std.testing.expect(v.eq(0.5) == false);
}

test "vec operations" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    const MyVec2 = packed struct {
        pub usingnamespace VecFns(@This());
        x: f32 = 0,
        y: f32 = 0,
    };

    var a: MyVec = .{ .x = 0, .y = 0 };
    var a2 = a.add(2).mul(10).divExact(10).sub(3);
    try std.testing.expect(a2.x == -1 and a2.y == -1);

    var b: MyVec2 = .{ .x = 0, .y = 0 };
    var b2 = b.add(2).mul(10).div(10).sub(3);
    try std.testing.expect(b2.x == -1 and b2.y == -1);

    var a3 = a2.add(a2).mul(a2).divExact(a2).sub(a2).into(MyVec2);
    var b3 = b2.add(b2).mul(b2).div(b2).sub(b2);
    try std.testing.expect(a3.eq(b3));
}
