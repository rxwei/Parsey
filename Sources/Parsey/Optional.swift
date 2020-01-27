//
//  Optional.swift
//  Funky
//
//  Created by Richard Wei on 8/28/16.
//
//

extension Optional : Mappable {
    public typealias MapSource = Wrapped
    public typealias MapTarget = Any
    public typealias MapResult = MapTarget?
}

extension Optional : FlatMappable {}

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

