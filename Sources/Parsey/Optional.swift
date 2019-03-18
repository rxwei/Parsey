//
//  Optional.swift
//  Funky
//
//  Created by Richard Wei on 8/28/16.
//
//

// MARK: - Internal disambiguator
internal extension Optional {
    @inline(__always)
    static func map<U>(_ function: (Wrapped) throws -> U, _ optional: Wrapped?) rethrows -> U? {
        return try optional.map(function)
    }

    @inline(__always)
    static func flatMap<U>(_ function: (Wrapped) throws -> U?, _ optional: Wrapped?) rethrows -> U? {
        return try optional.flatMap(function)
    }
}

extension Optional : Mappable {

    public typealias MapSource = Wrapped
    public typealias MapTarget = Any
    public typealias MapResult = MapTarget?

    public func map<MapTarget>(_ transform: (MapSource) throws -> MapTarget) rethrows -> MapTarget? {
        return try Optional.map(transform, self)
    }

}

extension Optional : ApplicativeMappable {

    public typealias ApplicativeTransform = ((MapSource) throws -> MapTarget)?

    public func apply<MapTarget>(_ transform: ((MapSource) throws -> MapTarget)?) throws -> MapTarget? {
        guard case let (f?, x?) = (transform, self) else {
            return nil
        }
        return try f(x)
    }

    public static func singleton(_ element: Wrapped) -> Wrapped? {
        return element
    }

}

extension Optional : FlatMappable {

    @inline(__always)
    public func flatMap<MapTarget>(_ transform: @escaping (MapSource) throws -> MapTarget?) -> MapTarget? {
        return flatMap(transform as (Wrapped) throws -> MapTarget?)
    }

}
