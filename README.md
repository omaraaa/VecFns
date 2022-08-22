# VecFns
Automatic vector math functions for your vector structs.

### Usage

Just add `VecFns` with `usingnamespace` to your struct, you will get the usual math functions for your vector. All fields of the struct should be the same type, and also be numeric. 

```zig
const VecFns = @import("./vec_fns.zig").VecFns;

const MyVec = struct {
  pub usingnamespace VecFns(@This());
  a: i32,
  b: i32,
  c: i32
};


const Vec2f = struct {
  pub usingnamespace VecFns(@This());
  x: f64,
  y: f64,
};

```

### Functions

The following functions will be in the namespace of your struct type after including `VecFns`.

```zig
// Applies a function `f` to the vector. `args` is any additional arguments to be passed to `f`.
fn map(self: Self, comptime f: anytype, args: anytype) Self

// Same as `map` but without args argument.
fn apply(self: Self, comptime f: anytype) Self

// Applies a function `f` to 2 vectors.
fn map2(a: anytype, b: anytype, comptime f: anytype, args: anytype) Self

// Same as `map`, reduces the vector into a single value.
fn reduce(self: Self, comptime f: anytype, args: anytype) T

// Adds either 2 vectors or a vector and a scalar value.
fn add(self: Self, other: anytype) Self

// Subtracts either 2 vectors or a vector and a scalar value.
fn sub(self: Self, other: anytype) Self

// Multiplies either 2 vectors or a vector and a scalar value.
fn mul(self: Self, other: anytype) Self

// Divides either 2 vectors or a vector and a scalar value.
fn div(self: Self, other: anytype) Self

// Same as div, but uses `@divExact`
fn divExact(self: Self, other: anytype) Self

// Same as div, but uses `@divFloor`
fn divFloor(self: Self, other: anytype) Self

// Returns the sum of the vector.
fn sum(self: Self) T

// Given 2 vectors or a vector and a scalar value, returns a vector with the maximum between the 2.
fn max(self: Self, other: Self) Self

// Given 2 vectors or a vector and a scalar value, returns a vector with the minimum between the 2.
fn min(self: Self, other: Self) Self

// Checks if the vector is equal to `other` (can be a vector or a scalar)
fn eq(self: Self, other: anytype) bool

// Attempts to covert/cast the vector into another vector type. 
fn into(self: Self, comptime VType: type) VType

// Joins two vector into a vector size 2\*N.
fn join(self: Self, other: Self) [2 * N]T

// Returns the zero vector.
fn zero() Self

// Returns a vector where all values are `n`.
fn all(n: anytype) Self

// Coverts the vector into an array of type `[N]T`.
fn toArray(self: Self) [N]T

// Create a vector from an array.
fn fromArray(array: [N]T) Self

// Length of the vector. (Float only)
fn len(self: Self) T

// Distance between 2 vectors. (Float only)
fn distance(self: Self, other: anytype) T

// Normalizes the vector values to [0, 1]. (Float only)
fn norm(self: Self) Self
