//
//  Function.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

// (f•g)(x) = f(g(x))
@inline(__always)
public func •<A, B, C>(f: @escaping (B) -> C, g: @escaping (A) -> B) -> (A) -> C {
    return { f(g($0)) }
}

// (f•g)(x, y) = f(g(x), g(y))
@inline(__always)
public func •<A, B, C>(f: @escaping (B, B) -> C, g: @escaping (A) -> B) -> (A, A) -> C {
    return { f(g($0), g($1)) }
}

// (f•g)(x) = f(x, g(y))
@inline(__always)
public func •<A, B, C>(f: @escaping (B, B) -> C, g: @escaping (A) -> B) -> (B, A) -> C {
    return { f($0, g($1)) }
}

// (f•g)(x) = f(g(x), y)
@inline(__always)
public func •<A, B, C>(f: @escaping (B, B) -> C, g: @escaping (A) -> B) -> (A, B) -> C {
    return { f(g($0), $1) }
}

// (f•g)(x, y) = f(g(x, y))
@inline(__always)
public func •<A, B, C, D>(f: @escaping (C) -> D, g: @escaping (A, B) -> C) -> (A, B) -> D {
    return { f(g($0, $1)) }
}

// (f•g)(x, y, z) = f(g(x, y, z))
@inline(__always)
public func •<A, B, C, D, E>(f: @escaping (D) -> E, g: @escaping (A, B, C) -> D) -> (A, B, C) -> E {
    return { f(g($0, $1, $2)) }
}

// (f•g)(x, y, z, a) = f(g(x, y, z, a))
@inline(__always)
public func •<A, B, C, D, E, F>(f: @escaping (E) -> F, g: @escaping (A, B, C, D) -> E) -> (A, B, C, D) -> F {
    return { f(g($0, $1, $2, $3)) }
}

// ((a, b) -> c) -> a -> b -> c
@inline(__always)
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { x in { y in f(x, y) } }
}
// ((a, b, c) -> d) -> a -> b -> c -> d
@inline(__always)
public func curry<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
    return { x in { y in { z in f(x, y, z) } } }
}

// ((a, b, c, d) -> e) -> a -> b -> c -> d -> e
@inline(__always)
public func curry<A, B, C, D, E>(_ f: @escaping (A, B, C, D) -> E) -> (A) -> (B) -> (C) -> (D) -> E {
    return { x in { y in { z in { a in f(x, y, z, a) } } } }
}

// ((a, b, c, d, e) -> f) -> a -> b -> c -> d -> e -> f
@inline(__always)
public func curry<A, B, C, D, E, F>(_ f: @escaping (A, B, C, D, E) -> F) -> (A) -> (B) -> (C) -> (D) -> (E) -> F {
    return { x in { y in { z in { a in { b in f(x, y, z, a, b) } } } } }
}

// ((a, b, c, d, e, f) -> g) -> a -> b -> c -> d -> e -> f -> g
@inline(__always)
public func curry<A, B, C, D, E, F, G>(_ f: @escaping (A, B, C, D, E, F) -> G) -> (A) -> (B) -> (C) -> (D) -> (E) -> (F) -> G {
    return { x in { y in { z in { a in { b in { c in f(x, y, z, a, b, c) } } } } } }
}

// (a -> b -> c) -> (a, b) -> c
@inline(__always)
public func uncurry<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (A, B) -> C {
    return { (x, y) in f(x)(y) }
}

// (a -> b -> c -> d) -> (a, b, c) -> d
@inline(__always)
public func uncurry<A, B, C, D>(_ f: @escaping (A) -> (B) -> (C) -> D) -> (A, B, C) -> D {
    return { (x, y, z) in f(x)(y)(z) }
}

// (a -> b -> c -> d -> e) -> (a, b, c, d) -> e
@inline(__always)
public func uncurry<A, B, C, D, E>(_ f: @escaping (A) -> (B) -> (C) -> (D) -> E) -> (A, B, C, D) -> E {
    return { (x, y, z, a) in f(x)(y)(z)(a) }
}

// (a -> b -> c -> d -> e -> f) -> (a, b, c, d, e) -> f
@inline(__always)
public func uncurry<A, B, C, D, E, F>(_ f: @escaping (A) -> (B) -> (C) -> (D) -> (E) -> F) -> (A, B, C, D, E) -> F {
    return { (x, y, z, a, b) in f(x)(y)(z)(a)(b) }
}

// (a -> b -> c -> d -> e -> f -> g) -> (a, b, c, d, e, f) -> g
@inline(__always)
public func uncurry<A, B, C, D, E, F, G>(_ f: @escaping (A) -> (B) -> (C) -> (D) -> (E) -> (F) -> G) -> (A, B, C, D, E, F) -> G {
    return { (x, y, z, a, b, c) in f(x)(y)(z)(a)(b)(c) }
}

// Flip argument order of a binary function
@inline(__always)
public func flip<A, B, C>(_ f: @escaping (A, B) -> C) -> (B, A) -> C {
    return { x, y in f(y, x) }
}

// Flip argument order of a curried binary function
@inline(__always)
public func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
    return { x in { y in f(y)(x) } }
}

// Fixed-Point combinator (simulated by recursion)
@available(*, renamed: "withFixedPoint")
public func fixedPoint<A, B>(_ f: @escaping (@escaping (A) -> B) -> (A) -> B) -> (A) -> B {
    return { f(fixedPoint(f))($0) }
}

public func withFixedPoint<A, B>(_ f: @escaping (@escaping (A) -> B) -> (A) -> B) -> (A) -> B {
    return { f(fixedPoint(f))($0) }
}
