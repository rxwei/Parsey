//
//  Numeric.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

#if !swift(>=4.0)
public protocol Numeric : ExpressibleByIntegerLiteral {
    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self
}

public protocol BinaryInteger {
    static func /(lhs: Self, rhs: Self) -> Self
    static func %(lhs: Self, rhs: Self) -> Self
}

extension Int8 : Numeric {}
extension Int16 : Numeric {}
extension Int32 : Numeric {}
extension Int64 : Numeric {}
extension Float : Numeric {}
extension Double : Numeric {}
extension Int8 : BinaryInteger {}
extension Int16 : BinaryInteger {}
extension Int32 : BinaryInteger {}
extension Int64 : BinaryInteger {}
#endif

public extension Numeric {

    static var additiveIdentity: Self {
        return 0
    }

    static var multiplicativeIdentity: Self {
        return 1
    }

}
