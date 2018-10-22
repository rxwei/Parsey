//
//  Operators.swift
//  Parsey
//
//  Created by Richard Wei on 10/21/18.
//

prefix operator +
prefix operator -
prefix operator *
prefix operator /
prefix operator %
prefix operator ==
prefix operator !=
postfix operator +
postfix operator -
postfix operator *
postfix operator /
postfix operator %

public extension Numeric {
    static prefix func +(rhs: Self) -> (Self) -> Self {
        return { $0 + rhs }
    }

    static prefix func -(rhs: Self) -> (Self) -> Self {
        return { $0 - rhs }
    }

    static prefix func *(rhs: Self) -> (Self) -> Self {
        return { $0 * rhs }
    }

    static postfix func +(lhs: Self) -> (Self) -> Self {
        return { lhs + $0 }
    }

    static postfix func -(lhs: Self) -> (Self) -> Self {
        return { lhs - $0 }
    }

    static postfix func *(lhs: Self) -> (Self) -> Self {
        return { lhs * $0  }
    }
}

public extension BinaryInteger {
    static prefix func /(rhs: Self) -> (Self) -> Self {
        return { $0 / rhs }
    }

    static prefix func %(rhs: Self) -> (Self) -> Self {
        return { $0 % rhs }
    }

    static postfix func /(lhs: Self) -> (Self) -> Self {
        return { lhs / $0 }
    }

    static postfix func %(lhs: Self) -> (Self) -> Self {
        return { lhs % $0 }
    }
}

public extension FloatingPoint {
    static prefix func /(rhs: Self) -> (Self) -> Self {
        return { $0 / rhs }
    }

    static postfix func /(lhs: Self) -> (Self) -> Self {
        return { lhs / $0 }
    }
}

public extension Comparable {
    static prefix func ==(rhs: Self) -> (Self) -> Bool {
        return { $0 == rhs }
    }

    static prefix func !=(rhs: Self) -> (Self) -> Bool {
        return { $0 != rhs }
    }
}
