//
//  Set.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

extension Set : Mappable {

    public typealias MapSource = Element
    public typealias MapTarget = AnyHashable
    public typealias MapResult = Set<MapTarget>

    public func map<MapTarget>(_ transform: (MapSource) throws -> MapTarget) rethrows -> Set<MapTarget> {
        return try reduce([]) { acc, x in try acc.union([transform(x)]) }
    }

}

extension Set : ApplicativeMappable {

    public typealias ApplicativeTransform = [(MapSource) throws -> MapTarget]

    public func apply<MapTarget>(_ transforms: [(MapSource) throws -> MapTarget]) throws -> Set<MapTarget> {
        return try transforms.reduce([]) { acc, f in try acc.union(self.map(f)) }
    }

    public static func singleton(_ element: Element) -> Set<Element> {
        return [element]
    }

}

extension Set : FlatMappable {
    public func flatMap<MapTarget>(_ transform: (MapSource) throws -> Set<MapTarget>) rethrows -> Set<MapTarget> {
        return try reduce([]) { acc, x in try acc.union(transform(x)) }
    }
}

extension Set : Reducible {}
