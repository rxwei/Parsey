//
//  Functional.swift
//  Parsey
//
//  Created by Richard Wei on 10/21/18.
//

// (a -> b -> c) -> (a, b) -> c
@usableFromInline
func uncurry<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (A, B) -> C {
    return { (x, y) in f(x)(y) }
}
