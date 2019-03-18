//
//  Reducible.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

public protocol Reducible {
    associatedtype Element
    func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) rethrows -> Result
}

public extension Reducible {
    public func mapReduce<Result: Associable>(_ transform: (Element) -> Result) -> Result {
        return reduce(Result.identity) { $0 + transform($1) }
    }
}

public extension Reducible where Element : Associable {
    @inline(__always)
    public func reduced() -> Element {
        return mapReduce{$0}
    }
}
