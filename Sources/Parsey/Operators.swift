//
//  Operator.swift
//  Funky
//
//  Created by Richard Wei on 8/27/16.
//
//

precedencegroup FunctionCompositionPrecedence {
    associativity: left
    higherThan:    MultiplicationPrecedence
    lowerThan:     BitwiseShiftPrecedence
}

infix operator • : FunctionCompositionPrecedence

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

    public static prefix func /(rhs: Self) -> (Self) -> Self {
        return { $0 / rhs }
    }

    public static postfix func /(lhs: Self) -> (Self) -> Self {
        return { lhs / $0 }
    }

}

public extension Comparable {
    
    public static prefix func ==(rhs: Self) -> (Self) -> Bool {
        return { $0 == rhs }
    }
    
    public static prefix func !=(rhs: Self) -> (Self) -> Bool {
        return { $0 != rhs }
    }

}
