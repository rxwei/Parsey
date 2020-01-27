//
//  Array.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

extension Array : Mappable {
    public typealias MapSource = Element
    public typealias MapTarget = Any
    public typealias MapResult = [MapTarget]
}
extension Array : FlatMappable { }

extension Array : ApplicativeMappable {

    public typealias ApplicativeTransform = [(MapSource) throws -> MapTarget]

    public func apply<MapTarget>(_ transforms: [(MapSource) throws -> MapTarget]) throws -> [MapTarget] {
        return try transforms.flatMap(map)
    }

    public static func singleton(_ element: Element) -> [Element] {
        return [element]
    }

}

extension Array : Associable {
    public static var identity: [Element] { return [] }
}

extension Array : Reducible {}
