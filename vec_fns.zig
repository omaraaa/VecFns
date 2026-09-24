//! VecFns — vector math with a chained API.
//!
//! `usingnamespace` was removed from Zig, so vector functions now live in a
//! concrete `Vec(N, T)` type instead of being mixed into your own structs.
//! Your own structs stay plain data types and are converted at the ends of a
//! computation with `from` and `into`:
//!
//! ```zig
//! const vec = @import("vec_fns.zig");
//!
//! const Pos = struct { x: f32, y: f32 };
//! const Vel = struct { dx: f32, dy: f32 };
//!
//! const V = vec.Vec(2, f32);
//! const p2 = V.from(pos).add(vel).mul(0.3).into(Pos);
//! ```
//!
//! `from` accepts another `Vec`, an array, a tuple, a scalar (broadcast to
//! every component) or any struct with `N` numeric fields (or a single
//! `[N]U` array field). `into` accepts the same shapes and casts the
//! component values element-wise (float <-> int conversions included).

const std = @import("std");

pub fn Vec(comptime dim: comptime_int, comptime elem: type) type {
    return struct {
        const Self = @This();

        pub const N = dim;
        pub const T = elem;

        data: [N]T,

        // ==================================================================
        // Constructors / conversions
        // ==================================================================

        /// Build a vector from another vector, an array, a tuple, a scalar
        /// (broadcast to all components) or a struct with `N` numeric fields
        /// (or a single `[N]U` array field).
        pub fn from(b: anytype) Self {
            const B = @TypeOf(b);
            if (comptime isVecLike(B)) {
                const arr = toArr(T, b);
                var r: [N]T = undefined;
                inline for (0..N) |i| r[i] = arr[i];
                return .{ .data = r };
            }
            var r: [N]T = undefined;
            inline for (0..N) |i| r[i] = cast(T, b);
            return .{ .data = r };
        }

        /// Convert this vector into another type: a `Vec`, an array, a tuple,
        /// or a struct with `N` numeric fields (or a single `[N]U` array
        /// field). Component types may differ; values are cast element-wise.
        pub fn into(self: Self, comptime VType: type) VType {
            if (VType == Self) return self;
            switch (@typeInfo(VType)) {
                .array => |a| {
                    dimCheck(a.len, VType);
                    var r: VType = undefined;
                    inline for (0..N) |i| r[i] = cast(a.child, self.data[i]);
                    return r;
                },
                .@"struct" => |s| {
                    if (s.is_tuple) {
                        dimCheck(s.field_types.len, VType);
                        var r: VType = undefined;
                        inline for (0..N) |i| r[i] = cast(s.field_types[i], self.data[i]);
                        return r;
                    } else if (s.field_types.len == 1 and @typeInfo(s.field_types[0]) == .array) {
                        const FT = s.field_types[0];
                        const fa = @typeInfo(FT).array;
                        dimCheck(fa.len, VType);
                        var arr: FT = undefined;
                        inline for (0..N) |i| arr[i] = cast(fa.child, self.data[i]);
                        var r: VType = undefined;
                        @field(r, s.field_names[0]) = arr;
                        return r;
                    } else {
                        dimCheck(s.field_types.len, VType);
                        var r: VType = undefined;
                        inline for (s.field_names, 0..) |name, i| {
                            @field(r, name) = cast(s.field_types[i], self.data[i]);
                        }
                        return r;
                    }
                },
                else => @compileError("Cannot convert a vector into " ++ @typeName(VType)),
            }
        }

        /// Convert the vector into an array of type `[N]T`.
        pub fn toArray(self: Self) [N]T {
            return self.data;
        }

        /// Create a vector from an array of type `[N]T`.
        pub fn fromArray(array: [N]T) Self {
            return .{ .data = array };
        }

        /// Create a vector from a tuple with `N` components.
        pub fn fromTuple(tuple: anytype) Self {
            return from(tuple);
        }

        /// Returns the zero vector.
        pub fn zero() Self {
            return .{ .data = std.mem.zeroes([N]T) };
        }

        /// Returns a vector where all components are `n`.
        pub fn all(n: anytype) Self {
            return from(n);
        }

        /// Runtime component access.
        pub fn get(self: Self, i: usize) T {
            return self.data[i];
        }

        // ==================================================================
        // Functional
        // ==================================================================

        /// Applies a function `f` to each component. `args` are any
        /// additional arguments passed to `f`.
        pub fn map(self: Self, comptime f: anytype, args: anytype) Self {
            var r: Self = undefined;
            inline for (0..N) |i| r.data[i] = @call(.auto, f, .{self.data[i]} ++ args);
            return r;
        }

        /// Same as `map` but without extra arguments.
        pub fn apply(self: Self, comptime f: anytype) Self {
            return self.map(f, .{});
        }

        /// Applies a function `f` component-wise to this vector and `other`
        /// (a vector, tuple, array, struct or broadcast scalar).
        pub fn map2(self: Self, other: anytype, comptime f: anytype, args: anytype) Self {
            return zip(self, other, f, args, T);
        }

        /// Folds the vector into a single value using `f`.
        pub fn reduce(self: Self, comptime f: anytype, args: anytype) T {
            var r: T = self.data[0];
            inline for (1..N) |i| r = @call(.auto, f, .{ r, self.data[i] } ++ args);
            return r;
        }

        fn zip(self: Self, other: anytype, comptime f: anytype, args: anytype, comptime R: type) Vec(N, R) {
            var r: [N]R = undefined;
            if (comptime isVecLike(@TypeOf(other))) {
                const o = toArr(T, other);
                inline for (0..N) |i| {
                    r[i] = @call(.auto, f, .{ self.data[i], o[i] } ++ args);
                }
            } else {
                inline for (0..N) |i| {
                    r[i] = @call(.auto, f, .{ self.data[i], cast(T, other) } ++ args);
                }
            }
            return .{ .data = r };
        }

        // ==================================================================
        // Arithmetic
        // ==================================================================

        /// Adds a vector or a scalar to each component.
        pub fn add(self: Self, other: anytype) Self {
            return self.map2(other, _add, .{});
        }
        /// Subtracts a vector or a scalar from each component.
        pub fn sub(self: Self, other: anytype) Self {
            return self.map2(other, _sub, .{});
        }
        /// Multiplies each component by a vector or a scalar.
        pub fn mul(self: Self, other: anytype) Self {
            return self.map2(other, _mul, .{});
        }
        /// Divides each component by a vector or a scalar (floats only).
        pub fn div(self: Self, other: anytype) Self {
            return self.map2(other, _div, .{});
        }
        /// Same as `div`, but uses `@divExact`.
        pub fn divExact(self: Self, other: anytype) Self {
            return self.map2(other, _divExact, .{});
        }
        /// Same as `div`, but uses `@divFloor`.
        pub fn divFloor(self: Self, other: anytype) Self {
            return self.map2(other, _divFloor, .{});
        }
        /// Same as `div`, but uses `@divTrunc`.
        pub fn divTrunc(self: Self, other: anytype) Self {
            return self.map2(other, _divTrunc, .{});
        }
        /// Subtraction clamping at zero to prevent underflow of unsigned types.
        pub fn sub0(self: Self, other: anytype) Self {
            return self.map2(other, _sub0, .{});
        }
        /// Linear interpolation between this vector and `other`.
        pub fn lerp(self: Self, other: anytype, a: T) Self {
            return self.map2(other, _lerp, .{a});
        }
        /// Component-wise maximum against a vector or a scalar.
        pub fn max(self: Self, other: anytype) Self {
            return self.map2(other, _max, .{});
        }
        /// Component-wise minimum against a vector or a scalar.
        pub fn min(self: Self, other: anytype) Self {
            return self.map2(other, _min, .{});
        }
        /// Clamps each component between `minimum` and `maximum`.
        pub fn clamp(self: Self, minimum: anytype, maximum: anytype) Self {
            return self.map2(minimum, _max, .{}).map2(maximum, _min, .{});
        }
        /// Returns a vector with every component set to `n`.
        pub fn set(self: Self, n: anytype) Self {
            return self.map2(n, _set, .{});
        }

        /// Returns the sum of all components.
        pub fn sum(self: Self) T {
            return self.reduce(_add, .{});
        }
        /// Returns the product of all components.
        pub fn prod(self: Self) T {
            return self.reduce(_mul, .{});
        }
        /// Dot product with `other`.
        pub fn dot(self: Self, other: anytype) T {
            return self.mul(other).sum();
        }

        // ==================================================================
        // Comparison
        // ==================================================================

        /// True if every component is equal to `other` (vector or scalar).
        pub fn eq(self: Self, other: anytype) bool {
            return zip(self, other, _eq, .{}, bool).reduce(_and, .{});
        }
        /// True if every component is greater than `other`.
        pub fn gt(self: Self, other: anytype) bool {
            return zip(self, other, _gt, .{}, bool).reduce(_and, .{});
        }
        /// True if every component is greater than or equal to `other`.
        pub fn gte(self: Self, other: anytype) bool {
            return zip(self, other, _gte, .{}, bool).reduce(_and, .{});
        }
        /// True if every component is less than `other`.
        pub fn lt(self: Self, other: anytype) bool {
            return zip(self, other, _lt, .{}, bool).reduce(_and, .{});
        }
        /// True if every component is less than or equal to `other`.
        pub fn lte(self: Self, other: anytype) bool {
            return zip(self, other, _lte, .{}, bool).reduce(_and, .{});
        }

        // ==================================================================
        // Float-only functions
        // ==================================================================

        /// Length of the vector. (float vectors only)
        pub fn len(self: Self) T {
            if (comptime !isFloat(T)) @compileError("len() is only available on float vectors");
            return std.math.sqrt(self.dot(self));
        }
        /// Alias of `len`.
        pub const length = len;

        /// Distance between two vectors. (float vectors only)
        pub fn distance(self: Self, other: anytype) T {
            return self.sub(other).len();
        }

        /// Returns the vector scaled to length 1. (float vectors only)
        pub fn norm(self: Self) Self {
            const l = self.len();
            if (l > 0 or l < 0) {
                return self.div(l);
            } else {
                return zero();
            }
        }

        /// Component-wise absolute value.
        pub fn abs(self: Self) Self {
            return self.apply(absOf);
        }

        // ==================================================================
        // Other
        // ==================================================================

        /// Reorder components. `indices` is either a tuple of indices
        /// (e.g. `.{1, 0, 0}`) or, for `N <= 10`, a string of digits
        /// where `'0'` is the first component (e.g. `"100"`).
        pub fn swizzle(self: Self, comptime indices: anytype) Vec(swizzleCount(indices), T) {
            const K = comptime swizzleCount(indices);
            var r: [K]T = undefined;
            inline for (0..K) |i| r[i] = self.data[swizzleIndex(indices, i)];
            return .{ .data = r };
        }

        /// Joins two vectors into an array of size `2 * N`.
        pub fn join(self: Self, other: Self) [2 * N]T {
            var array: [2 * N]T = undefined;
            inline for (0..N) |i| array[i] = self.data[i];
            inline for (0..N) |i| array[N + i] = other.data[i];
            return array;
        }

        // ==================================================================
        // Internals
        // ==================================================================

        fn isVecLike(comptime B: type) bool {
            return switch (@typeInfo(B)) {
                .array, .@"struct" => true,
                else => false,
            };
        }

        /// Converts a vector-like value into an array of `To`, casting each
        /// component element-wise.
        fn toArr(comptime To: type, b: anytype) [N]To {
            const B = @TypeOf(b);
            var r: [N]To = undefined;
            switch (@typeInfo(B)) {
                .@"struct" => |s| {
                    if (s.is_tuple) {
                        dimCheck(s.field_types.len, B);
                        inline for (0..N) |i| r[i] = cast(To, b[i]);
                    } else if (s.field_types.len == 1 and @typeInfo(s.field_types[0]) == .array) {
                        const fa = @typeInfo(s.field_types[0]).array;
                        dimCheck(fa.len, B);
                        const arr = @field(b, s.field_names[0]);
                        inline for (0..N) |i| r[i] = cast(To, arr[i]);
                    } else {
                        dimCheck(s.field_types.len, B);
                        inline for (s.field_names, 0..) |name, i| {
                            r[i] = cast(To, @field(b, name));
                        }
                    }
                },
                .array => |a| {
                    dimCheck(a.len, B);
                    inline for (0..N) |i| r[i] = cast(To, b[i]);
                },
                else => @compileError("toArr() called with a scalar"),
            }
            return r;
        }

        fn dimCheck(comptime count: comptime_int, comptime VType: type) void {
            if (count != N) {
                @compileError(std.fmt.comptimePrint(
                    "Cannot convert {s}: it has {d} components, expected {d}.",
                    .{ @typeName(VType), count, N },
                ));
            }
        }

        fn swizzleCount(comptime indices: anytype) comptime_int {
            switch (@typeInfo(@TypeOf(indices))) {
                .pointer => |p| {
                    if (p.size == .one) {
                        const ci = @typeInfo(p.child);
                        if (ci == .array and ci.array.child == u8) return ci.array.len;
                    }
                },
                .@"struct" => |s| {
                    if (s.is_tuple) return indices.len;
                },
                else => {},
            }
            @compileError("swizzle() expects a string of digits or a tuple of indices");
        }

        fn swizzleIndex(comptime indices: anytype, comptime i: usize) usize {
            return switch (@typeInfo(@TypeOf(indices))) {
                .pointer => indices[i] - '0',
                else => indices[i],
            };
        }
    };
}

// ============================================================================
// File-scope helpers
// ============================================================================

fn isFloat(comptime t: type) bool {
    return switch (@typeInfo(t)) {
        .float, .comptime_float => true,
        else => false,
    };
}

/// `@abs` widens signed ints to their unsigned counterpart, so cast back.
inline fn absOf(x: anytype) @TypeOf(x) {
    if (@typeInfo(@TypeOf(x)) == .float) return @abs(x);
    return @intCast(@abs(x));
}

/// Element-wise conversion between numeric types.
inline fn cast(comptime To: type, v: anytype) To {
    const From = @TypeOf(v);
    if (From == To) return v;
    const from = @typeInfo(From);
    const to = @typeInfo(To);
    if (from == .comptime_int or from == .comptime_float) return v;
    if (from == .float and to == .float) return @floatCast(v);
    if (from == .float and to == .int) return @intFromFloat(v);
    if (from == .int and to == .float) return @floatFromInt(v);
    if (from == .int and to == .int) return @intCast(v);
    @compileError("Cannot cast " ++ @typeName(From) ++ " to " ++ @typeName(To));
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

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "eq" {
    const V = Vec(2, f32);
    const v = V.from(0.5);
    try testing.expect(!v.eq(0));
    try testing.expect(v.eq(0.5));
}

test "vec operations" {
    const MyVec = Vec(2, i32);
    const MyVec2 = Vec(2, f32);

    const a = MyVec.from(0);
    const a2 = a.add(2).mul(10).divExact(10).sub(3);
    try testing.expectEqual(MyVec{ .data = .{ -1, -1 } }, a2);

    const b = MyVec2.from(0);
    const b2 = b.add(2).mul(10).div(10).sub(3);
    try testing.expectEqual(MyVec2{ .data = .{ -1, -1 } }, b2);

    const a3 = a2.add(a2).mul(a2).divExact(a2).sub(a2).into(MyVec2);
    const b3 = b2.add(b2).mul(b2).div(b2).sub(b2);
    try testing.expect(a3.eq(b3));
}

test "chained from/into with user structs" {
    const Pos = struct { x: f32, y: f32 };
    const Vel = struct { dx: f32, dy: f32 };
    const V = Vec(2, f32);

    const pos = Pos{ .x = 1, .y = 2 };
    const vel = Vel{ .dx = 0.5, .dy = -0.5 };

    const out = V.from(pos).add(vel).mul(0.3).into(Pos);
    try testing.expectApproxEqAbs(@as(f32, 0.45), out.x, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 0.45), out.y, 1e-6);

    // tuples, arrays and other vector types work too
    const t = V.from(.{ 1, 2 }).add(.{ 1, 1 }).into(struct { f32, f32 });
    try testing.expect(t[0] == 2 and t[1] == 3);
    const arr = V.from([2]f32{ 3, 4 }).into([2]f32);
    try testing.expectEqual([2]f32{ 3, 4 }, arr);
}

test "into conversions between int and float" {
    const F = Vec(2, f32);
    const I = Vec(2, i32);
    const Pos = struct { x: i32, y: i32 };

    const f = I.from(.{ 7, 9 }).into(F);
    try testing.expectEqual(F{ .data = .{ 7, 9 } }, f);

    const p = F.from(.{ 1.5, 2.5 }).into(Pos);
    try testing.expectEqual(Pos{ .x = 1, .y = 2 }, p);
}

test "division with signed integers" {
    // Note that div won't compile with signed integers and divExact will
    // produce a runtime panic if there is a remainder. So when using signed
    // integers you probably want either divFloor or divTrunc. If all values
    // are positive these two will behave the same. However when negative
    // values are in play they will produce different results:
    const MyVec = Vec(2, i32);

    // What happens when we divide -7 by 2?
    const a = MyVec.from(.{ -7, 1 });
    const b = MyVec.from(.{ 2, 1 });

    // divFloor rounds towards negative infinity
    const floor = a.divFloor(b);
    try testing.expectEqual(MyVec{ .data = .{ -4, 1 } }, floor);

    // while divTrunc behaves the way you probably expect integer division to work
    const trunc = a.divTrunc(b);
    try testing.expectEqual(MyVec{ .data = .{ -3, 1 } }, trunc);
}

test "swizzle" {
    const MyVec = Vec(2, i32);

    const a = MyVec.from(.{ 7, 12 });
    const b = a.swizzle(.{ 1, 0, 0, 1, 0 });
    try testing.expectEqual([5]i32{ 12, 7, 7, 12, 7 }, b.data);

    // a string of digits is equivalent
    const c = a.swizzle("10010");
    try testing.expectEqual([5]i32{ 12, 7, 7, 12, 7 }, c.data);
}

test "ordering" {
    const MyVec = Vec(2, i32);

    const a = MyVec.from(0);
    try testing.expect(a.gt(MyVec.from(.{ -1, -2 })));
    try testing.expect(a.gte(MyVec.from(.{ 0, 0 }))); // equal case
    try testing.expect(a.gte(MyVec.from(.{ -1, 0 })));
    try testing.expect(a.lt(MyVec.from(.{ 7, 1 })));
    try testing.expect(a.lte(MyVec.from(.{ 0, 0 }))); // equal case
    try testing.expect(a.lte(MyVec.from(.{ 1, 0 })));
    try testing.expect(a.lte(1)); // scalars broadcast
}

test "prod, sum and dot" {
    const MyVec = Vec(2, i32);

    const a = MyVec.from(.{ 10, 7 });
    try testing.expectEqual(@as(i32, 70), a.prod());
    try testing.expectEqual(@as(i32, 17), a.sum());
    try testing.expectEqual(@as(i32, 10), a.dot(.{ 1, 0 }));
}

test "clamp" {
    const MyVec = Vec(2, i32);

    var a = MyVec.from(.{ 10, -10 });
    const b = MyVec.from(0);
    const c = MyVec.from(5);
    try testing.expectEqual(MyVec{ .data = .{ 5, 0 } }, a.clamp(b, c));

    a = MyVec.from(.{ 3, 3 });
    try testing.expectEqual(a, a.clamp(b, c));
}

test "sub0" {
    const MyVec = Vec(2, u32);

    const a = MyVec.from(.{ 10, 10 });
    const b = MyVec.from(.{ 20, 2 });
    try testing.expectEqual(MyVec{ .data = .{ 0, 8 } }, a.sub0(b));
    const c = MyVec.from(.{ 10, 2 });
    try testing.expectEqual(MyVec{ .data = .{ 0, 8 } }, a.sub0(c));
}

test "float functions" {
    const V = Vec(2, f32);

    const a = V.from(.{ 3, 4 });
    try testing.expectApproxEqAbs(@as(f32, 5), a.len(), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 5), a.length(), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 5), a.distance(V.from(0)), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 1), a.norm().len(), 1e-6);
    try testing.expectEqual(V{ .data = .{ 3, 4 } }, V.from(.{ -3, 4 }).abs());
}

test "map, reduce, join, zero, all, set" {
    const V = Vec(3, i32);

    const a = V.from(.{ 1, 2, 3 });
    try testing.expectEqual(V.from(.{ 2, 4, 6 }), a.map(_mul, .{2}));
    try testing.expectEqual(V.from(.{ 2, 4, 6 }), a.mul(2));
    try testing.expectEqual(@as(i32, 6), a.sum());
    try testing.expectEqual(V.from(0), V.zero());
    try testing.expectEqual(V.from(7), V.all(7));
    try testing.expectEqual(V.from(9), a.set(9));
    try testing.expectEqual([6]i32{ 1, 2, 3, 4, 5, 6 }, a.join(V.from(.{ 4, 5, 6 })));
    try testing.expectEqual(V.from(.{ 1, 2, 3 }), V.fromArray(.{ 1, 2, 3 }));
    try testing.expectEqual([3]i32{ 1, 2, 3 }, a.toArray());
    try testing.expectEqual(@as(i32, 2), a.get(1));
}
