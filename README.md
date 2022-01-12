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

##### `fn map(self: Self, comptime f: anytype, args: anytype) Self` 

Applies a function `f` to the vector. `args` is any additional arguments to be passed to `f`.

##### `fn apply(self: Self, comptime f: anytype) Self` 

Same as `map` but without args argument.

##### `fn map2(a: anytype, b: anytype, comptime f: anytype, args: anytype) Self` 

Applies a function `f` to 2 vectors.

##### `fn reduce(self: Self, comptime f: anytype, args: anytype) T` 

same as `map`, reduces the vector into a single value.

##### `fn add(self: Self, other: anytype) Self` 

adds either a 2 vectors or a vector and a scalar value.

##### `fn sub(self: Self, other: anytype) Self` 

subtracts either a 2 vectors or a vector and a scalar value.

##### `fn mul(self: Self, other: anytype) Self` 

multiplies either a 2 vectors or a vector and a scalar value.

##### `fn div(self: Self, other: anytype) Self` 

divides either a 2 vectors or a vector and a scalar value.

##### `fn divExact(self: Self, other: anytype) Self` 

same as div, but uses `@divExact`

##### `fn divFloor(self: Self, other: anytype) Self` 

same as div, but uses `@divFloor`

##### `fn sum(self: Self) T` 

returns the sum of the vector.

##### `fn max(self: Self, other: Self) Self` 

given 2 vectors or a vector and a scalar value, returns a vector with the maximum between the 2.

##### `fn min(self: Self, other: Self) Self` 

given 2 vectors or a vector and a scalar value, returns a vector with the minimum between the 2.

##### `fn eq(self: Self, other: anytype) bool` 

checks if the vector is equal to `other` (can be a vector or a scalar)

##### `fn into(self: Self, comptime VType: type) VType` 

attempts to covert/cast the vector into another vector type. 

##### `fn join(self: Self, other: Self) [2 * N]T` 

joins two vector into a vector size 2\*N.

##### `fn zero() Self` 

returns the zero vector.

##### `fn all(n: anytype) Self` 

returns a vector where all values are `n`.

##### `fn toArray(self: Self) [N]T` 

coverts the vector into an array of type `[N]T`.

##### `fn fromArray(array: [N]T) Self` 

create a vector from an array.

##### `fn len(self: Self) T` 

length of the vector (float only).

##### `fn distance(self: Self, other: anytype) T` 

distance between 2 vectors (float only).

##### `fn norm(self: Self) Self` 

normalizes the vector (float ony).

