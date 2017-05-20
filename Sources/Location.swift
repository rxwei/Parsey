//
//  Location.swift
//  Parsey
//
//  Created by Richard Wei on 9/24/16.
//
//

/// Two dimentional text location with line number, column number and linear index
public protocol TextLocation : Strideable {
    var line: Int { set get }
    var column: Int { set get }
    var index: Int { set get }
    static var initialPosition: Int { get }
    init(line: Int, column: Int, index: Int)
}

public extension TextLocation {

    init() {
        self.init(line: Self.initialPosition, column: Self.initialPosition, index: 0)
    }

    public static func <(lhs: Self, rhs: Self) -> Bool {
        return lhs.index < rhs.index
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.column == rhs.column && lhs.line == rhs.line && lhs.index == rhs.index
    }

    public func advanced(byLines lines: Int, columns: Int, distance: Int) -> Self {
        return Self(line: line + lines, column: column + columns, index: index + distance)
    }

    public func advanced(by n: Int) -> Self {
        return Self(line: line, column: column + n, index: index + n)
    }

    public func advanced(past character: Character) -> Self {
        return character == "\n" ? newLine() : advanced(by: 1)
    }

    public static func + (lhs: Self, n: Int) -> Self {
        return lhs.advanced(by: n)
    }

    public func advanced<S: Sequence>(byScanning prefix: S) -> Self where S.Iterator.Element == Character {
        var new = self
        for char in prefix {
            if char == "\n" {
                new.line += 1
                new.column = Self.initialPosition
            } else {
                new.column += 1
            }
            new.index += 1
        }
        return new
    }

    public func newLine() -> Self {
        return Self(line: line + 1, column: Self.initialPosition, index: index + 1)
    }

    public mutating func advance(by n: Int) {
        column += n
        index += n
    }

    public mutating func advanceToNewLine() {
        line += 1
        column = Self.initialPosition
        index += 1
    }
    
    /// Returns a stride `x` such that `self.advanced(by: x)` approximates
    /// `other`.
    ///
    /// If `Stride` conforms to `Integer`, then `self.advanced(by: x) == other`.
    ///
    /// - Complexity: O(1).
    public func distance(to other: SourceLocation) -> Int {
        return other.index - index
    }

}

/// Text location for source code
/// Initial position starts from 1
public struct SourceLocation : TextLocation {

    public typealias Stride = Int

    public static let initialPosition = 1

    public var line, column, index: Int

    public init(line: Int, column: Int, index: Int) {
        self.line = line
        self.column = column
        self.index = index
    }

}

extension SourceLocation : CustomStringConvertible {
    public var description: String {
        return "\(line):\(column)"
    }
}
