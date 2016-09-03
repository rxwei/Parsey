//
//  Parser.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

public protocol TextLocation : Comparable {

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

}

public struct SourceLocation : TextLocation {

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

public typealias SourceRange = Range<SourceLocation>

public struct ParserInput {

    public typealias Stride = Int

    public let stream: String.CharacterView
    public let location: SourceLocation

    public var isEmpty: Bool {
        return stream.isEmpty
    }

    public var first: Character? {
        return stream.first
    }

    public var text: String {
        return String(stream)
    }

    public init(_ string: String, at location: SourceLocation = SourceLocation()) {
        self.stream = string.characters
        self.location = location
    }

    public init<S: Sequence>(_ stream: S, at location: SourceLocation = SourceLocation())
        where S.Iterator.Element == Character {
        self.stream = String.CharacterView(stream)
        self.location = location
    }

    public init(_ stream: String.CharacterView, at location: SourceLocation = SourceLocation()) {
        self.stream = stream
        self.location = location
    }

    public init(emptyStreamAt location: SourceLocation = SourceLocation()) {
        self.stream = String.CharacterView()
        self.location = location
    }

}

/// Temporary workaround for a code-breaking change introduced 
/// after the Swift 3 code-breaking change deadline.
/// FIXME: To be removed when Xcode 8 beta 7 comes out
extension Sequence where SubSequence : Sequence,
                         SubSequence.Iterator.Element == Iterator.Element,
                         SubSequence.SubSequence == SubSequence {
    public func prefix(while predicate: (Iterator.Element) throws -> Bool) rethrows -> AnySequence<Iterator.Element> {
        var result: [Iterator.Element] = []
        
        for element in self {
            guard try predicate(element) else {
                break
            }
            result.append(element)
        }
        return AnySequence(result)
    }
}

extension ParserInput : Sequence {

    public func prefix(_ maxLength: Int) -> ParserInput {
        return ParserInput(stream.prefix(maxLength), at: location)
    }

    public func prefix(while predicate: (Character) throws -> Bool) rethrows -> ParserInput {
        return try ParserInput(stream.prefix(while: predicate), at: location)
    }

    public func suffix(_ maxLength: Int) -> ParserInput {
        return ParserInput(stream.suffix(maxLength), at: location)
    }

    public typealias Iterator = String.CharacterView.Iterator
    public typealias SubSequence = ParserInput

    public func makeIterator() -> String.CharacterView.Iterator {
        return stream.makeIterator()
    }

    public func drop(while predicate: (Character) throws -> Bool) rethrows -> ParserInput {
        var newLoc = location
        var rest = stream
        for char in stream {
            guard try predicate(char) else { break }
            rest.removeFirst()
            if char == "\n" {
                newLoc.line += 1
                newLoc.column = 0
            } else {
                newLoc.column += 1
            }
        }
        return ParserInput(rest, at: newLoc)
    }

    public func dropFirst() -> ParserInput {
        guard let first = stream.first else { return self }
        let newLoc = first == "\n" ? location.newLine() : location.advanced(by: 1)
        return ParserInput(stream.dropFirst(), at: newLoc)
    }

    public func dropFirst(_ n: Int) -> ParserInput {
        let prefix = stream.prefix(n)
        let newLoc = prefix.reduce(location) { loc, x in
            x == "\n" ? location.newLine() : location.advanced(by: 1)
        }
        return ParserInput(stream.dropFirst(n), at: newLoc)
    }

    public func dropLast() -> ParserInput {
        return ParserInput(stream.dropLast(), at: location)
    }

    public func dropLast(_ n: Int) -> ParserInput {
        return ParserInput(stream.dropLast(n), at: location)
    }

    public func split(maxSplits: Int, omittingEmptySubsequences: Bool,
                      whereSeparator isSeparator: (Character) throws -> Bool) rethrows -> [ParserInput] {
        return try stream.split(maxSplits: maxSplits,
                                omittingEmptySubsequences: omittingEmptySubsequences,
                                whereSeparator: isSeparator).map { sub in ParserInput(sub) }
    }

}

extension ParserInput : CustomStringConvertible {

    public var description: String {
        let streamPrint = String(stream.prefix(50))
        return "\(location) ----\n\(streamPrint)"
    }

}

public struct Parse<Target> {
    public var target: Target
    public var range: Range<SourceLocation>
    public var rest: ParserInput
}

extension Parse : CustomStringConvertible {

    public var description: String {
        return "\(range) : \(target)"
    }

}

public struct Parser<Target> {

    public typealias Input = ParserInput

    public var run: (Input) throws -> Parse<Target>

    public init(run: @escaping (Input) throws -> Parse<Target>) {
        self.run = run
    }

    public init(success target: Target) {
        self.init { input in
            Parse(target: target, range: input.location..<input.location, rest: input)
        }
    }

    public init(failure: ParseFailure) {
        self.init { _ in throw failure }
    }

    public func parse(_ input: String) throws -> Target {
        return try parse(ParserInput(input))
    }
    
    public func parse(_ input: Input) throws -> Target {
        do {
            let output = try run(input)
            guard output.rest.isEmpty else { throw ParseFailure(extraInputAt: output.rest) }
            return output.target
        }
    }

    @available(*, deprecated, message: "Use | operator instead")
    public func or(_ other: @autoclosure @escaping () -> Parser<Target>) -> Parser<Target> {
        return Parser { input in
            do {
                return try self.run(input)
            }
            catch let failure as ParseFailure {
                if failure.irrecoverable { throw failure }
                else { return try other().run(input) }
            }
        }
    }

    public static func |(_ lhs: Parser<Target>,
                         _ rhs: @autoclosure @escaping () -> Parser<Target>) -> Parser<Target> {
        return Parser { input in
            do {
                return try lhs.run(input)
            }
            catch let failure as ParseFailure {
                if failure.irrecoverable { throw failure }
                else { return try rhs().run(input) }
            }
        }
    }

}

extension Parser : FlatMappable {
    public typealias MapSource = Target
    public typealias MapTarget = Any
    public typealias MapResult = Parser<MapTarget>
    public typealias ApplicativeTransform = Parser<(Target) -> MapTarget>

    public static func singleton(_ element: (Target)) -> Parser<Target> {
        return Parser(success: element)
    }
    
    public func map<MapTarget>(_ transform: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            return Parse(target: transform(out.target), range: out.range, rest: out.rest)
        }
    }

    public func apply<MapTarget>(_ transform: Parser<(Target) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out1 = try transform.run(input)
            let out2 = try self.run(out1.rest)
            return Parse(target: out1.target(out2.target), range: out2.range, rest: out2.rest)
        }
    }

   public func flatMap<MapTarget>(_ transform: @escaping (Target) -> Parser<MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let out2 = try transform(out.target).run(out.rest)
            return Parse(target: out2.target, range: input.location..<out2.range.upperBound, rest: out2.rest)
        }
    }

    public func mapParse<MapTarget>(_ transform: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            return Parse(target: transform(out), range: out.range, rest: out.rest)
        }
    }

    public func applyParse<MapTarget>(_ transform: Parser<(Parse<Target>) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out1 = try transform.run(input)
            let out2 = try self.run(out1.rest)
            return Parse(target: out1.target(out2), range: out2.range, rest: out2.rest)
        }
    }

   public func flatMapParse<MapTarget>(_ transform: @escaping (Parse<Target>) -> Parser<MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let out2 = try transform(out).run(out.rest)
            return Parse(target: out2.target, range: input.location..<out2.range.upperBound, rest: out2.rest)
        }
    }

}
