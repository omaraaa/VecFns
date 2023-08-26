const builtin = @import("builtin");
const std = @import("std");
const meta = std.meta;

pub fn VecFns(comptime Self: type) type {
    comptime var NN = @typeInfo(Self).Struct.fields.len;
    comptime var TT = @typeInfo(Self).Struct.fields[0].type;
    comptime {
        if (@typeInfo(TT) == .Array) {
            if (NN > 1) {
                @compileError("Generic Vec can only have 1 field.");
            }
            NN = @typeInfo(TT).Array.len;
            TT = @typeInfo(TT).Array.child;
        } else {
            inline for (@typeInfo(Self).Struct.fields) |f| {
                if (TT != f.type) {
                    @compileError("All fields of a Vec must be of the same type");
                }
            }
        }
    }
    return struct {
        pub usingnamespace VecFloat(Self, TT);
        pub usingnamespace VecToArray(Self, NN, TT);

        pub const T = TT;
        pub const N = NN;

        pub fn map(self: Self, comptime f: anytype, args: anytype) Self {
            var r: getArrayType() = undefined;
            var v1 = self.toArray();

            comptime var i = 0;
            inline while (i < N) : (i += 1) {
                r[i] = @call(.auto, f, .{v1[i]} ++ args);
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
            if (isStruct) {
                comptime var isTuple = other_info.Struct.is_tuple;
                var v2 = if (!isTuple) b.toArray() else b;
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = @call(.auto, f, .{ v1[i], v2[i] } ++ args);
                }
            } else {
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = @call(.auto, f, .{ v1[i], b } ++ args);
                }
            }
            return Self.fromArray(r);
        }
        pub fn reduce(self: Self, comptime f: anytype, args: anytype) T {
            var v1 = self.toArray();
            var r: T = v1[0];
            comptime var i = 1;
            inline while (i < N) : (i += 1) {
                r = @call(.auto, f, .{ r, v1[i] } ++ args);
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
        /// Subtraction clamping at zero to prevent underflow of unsigned types
        pub fn sub0(self: Self, other: anytype) Self {
            return map2(self, other, _sub0, .{});
        }
        pub fn lerp(self: Self, other: anytype, a: T) Self {
            return map2(self, other, _lerp, .{a});
        }
        pub fn sum(self: Self) T {
            return self.reduce(_add, .{});
        }
        pub fn prod(self: Self) T {
            return self.reduce(_mul, .{});
        }
        pub fn divExact(self: Self, other: anytype) Self {
            return map2(self, other, _divExact, .{});
        }
        pub fn divFloor(self: Self, other: anytype) Self {
            return map2(self, other, _divFloor, .{});
        }
        pub fn divTrunc(self: Self, other: anytype) Self {
            return map2(self, other, _divTrunc, .{});
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
        pub fn clamp(self: Self, minimum: anytype, maximum: anytype) Self {
            return map2(self, minimum, _max, .{}).map2(maximum, _min, .{});
        }
        pub fn eq(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _eq, .{}).reduce(_and, .{});
        }
        pub fn gt(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _gt, .{}).reduce(_and, .{});
        }
        pub fn gte(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _gte, .{}).reduce(_and, .{});
        }
        pub fn lt(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _lt, .{}).reduce(_and, .{});
        }
        pub fn lte(self: Self, other: anytype) bool {
            return GenericVec(N, bool).map2(self, other, _lte, .{}).reduce(_and, .{});
        }

        pub fn dot(self: Self, other: anytype) T {
            return self.mul(other).sum();
        }
        pub fn length(self: Self) T {
            return std.math.sqrt(self.dot(self));
        }

        pub fn into(self: Self, comptime VType: type) VType {
            if (comptime N != VType.N) {
                @compileError("Can't convert into type. Both vectors must have the same dimension.");
            }
            if (comptime T == VType.T and @sizeOf(Self) == @sizeOf(VType)) {
                return @as(VType, @bitCast(self));
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
                                    r[i] = @as(VType.T, @floatCast(v[i]));
                                },
                                .Int => {
                                    r[i] = @as(VType.T, @intFromFloat(v[i]));
                                },
                                else => unreachable,
                            }
                        },
                        .Int => {
                            switch (@typeInfo(VType.T)) {
                                .Float => {
                                    r[i] = @as(VType.T, @floatFromInt(v[i]));
                                },
                                .Int => {
                                    r[i] = @as(VType.T, @intCast(v[i]));
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
            for (v1, 0..) |v, i| {
                array[i] = v;
            }
            for (v2, 0..) |v, i| {
                array[N + i] = v;
            }
            return array;
        }
        pub fn zero() Self {
            return std.mem.zeroes(Self);
        }
        pub fn all(n: anytype) Self {
            var r: getArrayType() = undefined;
            for (&r) |*e| {
                e.* = n;
            }
            return Self.fromArray(r);
        }
        pub fn getArrayType() type {
            return [N]T;
        }

        /// Return a GenericVec containing the values indicated by `fields`.
        /// All selected fields must have single-character names (e.g. `x`)
        pub fn swizzle(self: Self, comptime fields: []const u8) GenericVec(fields.len, T) {
            var ret: GenericVec(fields.len, T) = undefined;
            inline for (fields, 0..) |member, i| {
                ret.data[i] = @field(self, &[_]u8{member});
            }
            return ret;
        }

        pub fn set(self: Self, n: anytype) Self {
            return map2(self, n, _set, .{});
        }

        pub fn from(b: anytype) Self {
            var r: getArrayType() = undefined;
            comptime var other_info = @typeInfo(@TypeOf(b));
            comptime var isStruct = other_info == .Struct;
            if (isStruct) {
                comptime var isTuple = other_info.Struct.is_tuple;
                var v2 = if (!isTuple) b.toArray() else b;
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = v2[i];
                }
            } else {
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = b;
                }
            }
            return Self.fromArray(r);
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
    if (@typeInfo(Self).Struct.fields[0].type == [N]T) {
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
                var r: [N]T = undefined;
                comptime var i = 0;
                inline while (i < N) : (i += 1) {
                    r[i] = @field(self, @typeInfo(Self).Struct.fields[i].name);
                }
                return r;
            }
            pub fn fromArray(array: [N]T) Self {
                var r: Self = undefined;
                inline for (meta.fields(Self), 0..) |f, i| {
                    const name = f.name;
                    @field(r, name) = array[i];
                }
                return r;
            }
            pub fn fromTuple(tuple: anytype) Self {
                var r: Self = undefined;
                inline for (meta.fields(Self), 0..) |f, i| {
                    const name = f.name;
                    @field(r, name) = tuple[i];
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
            pub fn abs(self: Self) Self {
                return self.apply(fabs);
            }
        };
    } else {
        return struct {
            pub fn abs(self: Self) Self {
                return self.apply(std.math.absInt);
            }
        };
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
inline fn _sub0(a: anytype, b: anytype) @TypeOf(a) {
    return if (a > b) a - b else 0;
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
inline fn _divTrunc(a: anytype, b: anytype) @TypeOf(a) {
    return @divTrunc(a, b);
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
inline fn _gt(a: anytype, b: anytype) bool {
    return a > b;
}
inline fn _gte(a: anytype, b: anytype) bool {
    return a >= b;
}
inline fn _lt(a: anytype, b: anytype) bool {
    return a < b;
}
inline fn _lte(a: anytype, b: anytype) bool {
    return a <= b;
}

inline fn _set(_: anytype, b: anytype) @TypeOf(b) {
    return b;
}

inline fn fabs(x: anytype) @TypeOf(x) {
    return @fabs(x);
}

test "VecFns.eq" {
    const V = struct {
        pub usingnamespace VecFns(@This());
        x: f32 = 0.5,
        y: f32 = 0.5,
    };

    var v: V = .{};
    try std.testing.expect(!v.eq(0));
    try std.testing.expect(v.eq(0.5));
}

test "vec operations" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    const MyVec2 = extern struct {
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

test "division with signed integers" {
    // Note that div won't compile with signed integers and divExact will
    //  produce a runtime panic if there is a remainder.  So when using
    //  signed integers you should probably want to use either divFloor or
    //  divTrunc.  If all values are positive these two will behave the same.
    //  However when negative values are in play they will produce different
    //  results:
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    // What happens when we divide -7 by 2?
    const a = MyVec{ .x = -7, .y = 1 };
    const b = MyVec{ .x = 2, .y = 1 };

    // divFloor rounds towards negative infinity
    const floor = a.divFloor(b);
    try std.testing.expect(floor.x == -4 and floor.y == 1);

    // while divTrunc behaves the way you probably expect integer division to work
    const trunc = a.divTrunc(b);
    try std.testing.expect(trunc.x == -3 and trunc.y == 1);
}

test "swizzle" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    var a: MyVec = .{ .x = 7, .y = 12 };
    var b = a.swizzle("yxxyx");
    try std.testing.expectEqual(a.y, b.data[0]);
    try std.testing.expectEqual(a.x, b.data[1]);
    try std.testing.expectEqual(a.x, b.data[2]);
    try std.testing.expectEqual(a.y, b.data[3]);
    try std.testing.expectEqual(a.x, b.data[4]);
}

test "ordering" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    var a: MyVec = .{ .x = 0, .y = 0 };
    try std.testing.expect(a.gt(MyVec{ .x = -1, .y = -2 }));
    try std.testing.expect(a.gte(MyVec{ .x = 0, .y = 0 })); // equal case
    try std.testing.expect(a.gte(MyVec{ .x = -1, .y = 0 }));
    try std.testing.expect(a.lt(MyVec{ .x = 7, .y = 1 }));
    try std.testing.expect(a.lte(MyVec{ .x = 0, .y = 0 })); // equal case
    try std.testing.expect(a.lte(MyVec{ .x = 1, .y = 0 }));
}

test "prod" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    const a = MyVec{ .x = 10, .y = 7 };
    try std.testing.expectEqual(@as(i32, 70), a.prod());
}

test "clamp" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: i32 = 0,
        y: i32 = 0,
    };

    var a = MyVec{ .x = 10, .y = -10 };
    const b = MyVec{ .x = 0, .y = 0 };
    const c = MyVec{ .x = 5, .y = 5 };
    try std.testing.expectEqual(MyVec{ .x = 5, .y = 0 }, a.clamp(b, c));

    a = MyVec{ .x = 3, .y = 3 };
    try std.testing.expectEqual(a, a.clamp(b, c));
}

test "sub0" {
    const MyVec = struct {
        pub usingnamespace VecFns(@This());
        x: u32 = 0,
        y: u32 = 0,
    };

    const a = MyVec{ .x = 10, .y = 10 };
    const b = MyVec{ .x = 20, .y = 2 };
    try std.testing.expectEqual(MyVec{ .x = 0, .y = 8 }, a.sub0(b));
    const c = MyVec{ .x = 10, .y = 2 };
    try std.testing.expectEqual(MyVec{ .x = 0, .y = 8 }, a.sub0(c));
}
