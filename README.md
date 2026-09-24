# VecFns
Vector math with a chained API.

`usingnamespace` was removed from Zig, so vector functions now live in a concrete `Vec(N, T)` type. Your own structs stay plain data types and are converted at the ends of a computation with `from` and `into`:

```zig
const vec = @import("./vec_fns.zig");

const Pos = struct { x: f32, y: f32 };
const Vel = struct { dx: f32, dy: f32 };

const V = vec.Vec(2, f32);

const p2 = V.from(pos).add(vel).mul(0.3).into(Pos);
```

### Conversions

`from` accepts:

* another `Vec` (component values are cast element-wise),
* an array `[N]U`,
* a tuple (e.g. `.{ 1, 2 }`),
* a scalar, broadcast to every component (e.g. `V.zero()` is `V.from(0)`),
* any struct with `N` numeric fields, or a single `[N]U` array field.

`into` accepts the same shapes (e.g. a `Vec`, an array, a tuple, or your own `Pos` struct) and casts the component values element-wise, including float <-> int conversions.

### Functions

```zig
// Build a vector from another vector, array, tuple, scalar or vec-like struct.
fn from(b: anytype) Self

// Convert into a Vec, array, tuple or vec-like struct (element-wise casts).
fn into(self: Self, comptime VType: type) VType

// Applies a function `f` to each component. `args` is any additional arguments to be passed to `f`.
fn map(self: Self, comptime f: anytype, args: anytype) Self

// Same as `map` but without args argument.
fn apply(self: Self, comptime f: anytype) Self

// Applies a function `f` component-wise to this vector and `other`.
fn map2(self: Self, other: anytype, comptime f: anytype, args: anytype) Self

// Folds the vector into a single value using `f`.
fn reduce(self: Self, comptime f: anytype, args: anytype) T

// Adds either 2 vectors or a vector and a scalar value.
fn add(self: Self, other: anytype) Self

// Subtracts either 2 vectors or a vector and a scalar value.
fn sub(self: Self, other: anytype) Self

// Subtraction clamping at zero to prevent underflow of unsigned types.
fn sub0(self: Self, other: anytype) Self

// Multiplies either 2 vectors or a vector and a scalar value.
fn mul(self: Self, other: anytype) Self

// Divides either 2 vectors or a vector and a scalar value.
fn div(self: Self, other: anytype) Self

// Same as div, but uses `@divExact`
fn divExact(self: Self, other: anytype) Self

// Same as div, but uses `@divFloor`
fn divFloor(self: Self, other: anytype) Self

// Same as div, but uses `@divTrunc`
fn divTrunc(self: Self, other: anytype) Self

// Linear interpolation between two vectors.
fn lerp(self: Self, other: anytype, a: T) Self

// Given 2 vectors or a vector and a scalar value, returns a vector with the maximum between the 2.
fn max(self: Self, other: anytype) Self

// Given 2 vectors or a vector and a scalar value, returns a vector with the minimum between the 2.
fn min(self: Self, other: anytype) Self

// Clamps each component between `minimum` and `maximum`.
fn clamp(self: Self, minimum: anytype, maximum: anytype) Self

// Returns a vector where all values are `n`.
fn set(self: Self, n: anytype) Self

// Returns the sum of the vector.
fn sum(self: Self) T

// Returns the product of the vector.
fn prod(self: Self) T

// Dot product with `other`.
fn dot(self: Self, other: anytype) T

// Checks if every component is equal to `other` (can be a vector or a scalar)
fn eq(self: Self, other: anytype) bool

// Likewise for >, >=, < and <=.
fn gt/gte/lt/lte(self: Self, other: anytype) bool

// Reorders components. `indices` is a tuple of indices (e.g. `.{1, 0, 0}`)
// or, for N <= 10, a string of digits where '0' is the first component.
fn swizzle(self: Self, comptime indices: anytype) Vec(indices.len, T)

// Joins two vectors into an array of size 2*N.
fn join(self: Self, other: Self) [2 * N]T

// Returns the zero vector.
fn zero() Self

// Returns a vector where all values are `n`.
fn all(n: anytype) Self

// Converts the vector into an array of type `[N]T`.
fn toArray(self: Self) [N]T

// Creates a vector from an array of type `[N]T`.
fn fromArray(array: [N]T) Self

// Runtime component access.
fn get(self: Self, i: usize) T

// Length of the vector. (Float only)
fn len(self: Self) T

// Alias of `len`. (Float only)
fn length(self: Self) T

// Distance between 2 vectors. (Float only)
fn distance(self: Self, other: anytype) T

// Returns the vector scaled to length 1. (Float only)
fn norm(self: Self) Self

// Component-wise absolute value.
fn abs(self: Self) Self
```
