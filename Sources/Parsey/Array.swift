//
//  Array.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

// MARK: - Internal disambiguator
internal extension Sequence {
    @inline(__always)
    static func map<U>(_ function: (Element) throws -> U, _ sequence: Self) rethrows -> [U] {
        return try sequence.map(function)
    }

    @inline(__always)
    static func flatMap<S : Sequence>(_ function: (Element) throws -> S, _ sequence: Self) rethrows -> [S.Element] {
        return try sequence.flatMap(function)
    }
}

extension Array : Mappable {
    public typealias MapSource = Element
    public typealias MapTarget = Any
    public typealias MapResult = [MapTarget]

    public func map<MapTarget>(_ transform: (MapSource) throws -> MapTarget) rethrows -> [MapTarget] {
        return try Array.map(transform, self)
    }

}

extension Array : ApplicativeMappable {

    public typealias ApplicativeTransform = [(MapSource) throws -> MapTarget]

    public func apply<MapTarget>(_ transforms: [(MapSource) throws -> MapTarget]) throws -> [MapTarget] {
        return try transforms.flatMap(map)
    }

    public static func singleton(_ element: Element) -> [Element] {
        return [element]
    }

}

extension Array : FlatMappable {

    public func flatMap<MapTarget>(_ transform: @escaping (MapSource) throws -> [MapTarget]) rethrows -> [MapTarget] {
        return try Array.flatMap(transform, self)
    }

}

extension Array : Associable {

    public static var identity: [Element] {
        return []
    }

}

extension Array : Reducible {}
