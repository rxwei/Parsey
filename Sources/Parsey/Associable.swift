//
//  Associable.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

/// Monoid
public protocol Associable {
    static var identity: Self { get }
    static func +(_: Self, _: Self) -> Self
}

extension String : Associable {
    public static var identity: String {
        return ""
    }
}
