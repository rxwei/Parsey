//
//  Parser.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

/// Two dimentional text location with line number, column number and linear index
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

/// Text location for source code
/// Initial position starts from 1
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

/// Range from a source location to another, for range tracking
public typealias SourceRange = Range<SourceLocation>

/// Input with location tracking
public struct ParserInput {

    public let lineStream: String.CharacterView
    
    public let location: SourceLocation

    public var stream: String.CharacterView {
        return lineStream.dropFirst(columnIndex)
    }

    public var line: String {
        return String(lineStream.prefix(while: !="\n"))
    }

    public var columnIndex: Int {
        return location.column - 1
    }

    public var isEmpty: Bool {
        return stream.isEmpty
    }

    public var first: Character? {
        return stream.first
    }

    public var text: String {
        return String(stream)
    }

    public init(_ string: String) {
        self.lineStream = string.characters
        self.location = .init()
    }

    public init<S: Sequence>(_ stream: S) where S.Iterator.Element == Character {
        self.lineStream = String.CharacterView(stream)
        self.location = .init()
    }

    internal init(lineStream: String.CharacterView, at location: SourceLocation = SourceLocation()) {
        self.lineStream = lineStream
        self.location = location
    }

    internal init() {
        self.lineStream = String.CharacterView()
        self.location = SourceLocation()
    }

}

/// FIXME: Implement indexing for line stream

/// To be removed when `Sequence.prefix(while:)` is implemented in the standard library
extension Sequence where SubSequence : Sequence,
                         SubSequence.Iterator.Element == Iterator.Element,
                         SubSequence.SubSequence == SubSequence {
    public func prefix(while predicate: (Iterator.Element) throws -> Bool)
        rethrows -> AnySequence<Iterator.Element> {
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
        return ParserInput(lineStream: lineStream.prefix(maxLength), at: location)
    }

    public func suffix(_ maxLength: Int) -> ParserInput {
        let prefixLength = stream.count - maxLength
        return prefixLength < 0 ? self : dropFirst(prefixLength)
    }

    public typealias Iterator = String.CharacterView.Iterator
    public typealias SubSequence = ParserInput

    public func makeIterator() -> String.CharacterView.Iterator {
        return stream.makeIterator()
    }

    public func drop(while predicate: (Character) throws -> Bool) rethrows -> ParserInput {
        var newLoc = location
        var newLinePrefixLength = 0
        for char in stream {
            guard try predicate(char) else { break }
            if char == "\n" {
                newLinePrefixLength += newLoc.column
                newLoc.line += 1
                newLoc.column = 1
            } else {
                newLoc.column += 1
            }
        }
        return ParserInput(lineStream: lineStream.dropFirst(newLinePrefixLength), at: newLoc)
    }

    public func dropFirst() -> ParserInput {
        guard let first = stream.first else { return self }
        let (newStream, newLoc) = first == "\n"
                                ? (lineStream.dropFirst(location.column), location.newLine())
                                : (lineStream, location.advanced(by: 1))
        return ParserInput(lineStream: newStream, at: newLoc)
    }

    public func dropFirst(_ n: Int) -> ParserInput {
        let prefix = stream.prefix(n)
        let (newStream, newLoc) = prefix.reduce((lineStream, location)) { acc, x in
            x == "\n" ? (acc.0.dropFirst(), acc.1.newLine())
                      : (acc.0, acc.1.advanced(by: 1))
        }
        return ParserInput(lineStream: newStream, at: newLoc)
    }

    public func dropLast() -> ParserInput {
        return ParserInput(lineStream: stream.dropLast(), at: location)
    }

    public func dropLast(_ n: Int) -> ParserInput {
        return ParserInput(lineStream: stream.dropLast(n), at: location)
    }

    /// TODO: Need location tracking!
    /// It does not matter for the parser since it's never used
    public func split(maxSplits: Int, omittingEmptySubsequences: Bool,
                      whereSeparator isSeparator: (Character) throws -> Bool) rethrows -> [ParserInput] {
        return try stream.split(maxSplits: maxSplits,
                                omittingEmptySubsequences: omittingEmptySubsequences,
                                whereSeparator: isSeparator).map { sub in ParserInput(sub) }
    }

}

extension ParserInput : CustomStringConvertible {

    public var description: String {
        let index = line.index(line.startIndex, offsetBy: columnIndex)
        let prefixLength = lineStream.prefix(upTo: index).count
        let suffixLength = line.characters.count - prefixLength
        var locator = Array<Character>(repeating: " ", count: prefixLength)
        locator.append("^")
        if suffixLength != 0 {
            for _ in 1..<suffixLength { locator.append("~") }
        }
        return "\(location) ----\n\(line)\n\(String(locator))"
    }

}

/// Parse - noun. the result obtained by parsing a string or a text 
/// Origin: mid 16th cent.: perhaps from Middle English pars ‘parts of speech,’
///         from Old French pars ‘parts’ (influenced by Latin pars ‘part’).
public struct Parse<Target> {

    /// Target data structure from the parse
    /// For example, with an s-expression parser:
    ///     "1" gets parsed to .integer(1)
    ///     "(+ 1 2)" gets parsed to .sExpression(.symbol(+), .integer(1), .integer(2))
    public var target: Target
    
    /// Source range from the beginning of this parse to the end
    /// For example, with an s-expression parser:
    ///     The parse of "1" has range 1:1..<1:2
    ///     The parse of the integer 1 in "(+ 1 2)" has range 1:4..<1:5
    public var range: SourceRange

    /// Rest of the stream to be parsed
    public var rest: ParserInput
}

extension Parse : CustomStringConvertible {
    public var description: String {
        return "\(range) : \(target)"
    }
}

/// Generic parser structure
public struct Parser<Target> {

    public typealias Input = ParserInput

    /// Embedded parsing function
    public var run: (Input) throws -> Parse<Target>

    /// Custom parser initializer
    public init(run: @escaping (Input) throws -> Parse<Target>) {
        self.run = run
    }

    /// Create a parser that always succeeds and outputs the specified target
    public init(success target: Target) {
        self.init { input in
            Parse(target: target, range: input.location..<input.location, rest: input)
        }
    }

    /// Create a parser that always fails with the specified failure
    public init(failure: ParseFailure) {
        self.init { _ in throw failure }
    }

    /// Parse a string
    public func parse(_ input: String) throws -> Target {
        return try parse(ParserInput(input))
    }

    private func parse(_ input: Input) throws -> Target {
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

    /// | : 'Or' operator
    /// If the left parser fails with a trivial (recoverrable) error,
    /// then try the parser on the right side.
    public static func |
        (lhs: Parser<Target>,
         rhs: @autoclosure @escaping () -> Parser<Target>) -> Parser<Target> {
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

/// Monad
extension Parser : FlatMappable {
    public typealias MapSource = Target
    public typealias MapTarget = Any
    public typealias MapResult = Parser<MapTarget>
    public typealias ApplicativeTransform = Parser<(Target) -> MapTarget>

    public static func singleton(_ element: (Target)) -> Parser<Target> {
        return Parser(success: element)
    }

    /// Transform the target to another
    public func map<MapTarget>(_ transform: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            return Parse(target: transform(out.target), range: out.range, rest: out.rest)
        }
    }

    /// Apply the function result of a parser to the target
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

    /// Transform the parse to another
    /// The parse (not parser!) contains source range information
    public func mapParse<MapTarget>(_ transform: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            return Parse(target: transform(out), range: out.range, rest: out.rest)
        }
    }

    /// Apply the function result of a parser to the target
    /// The parse (not parser!) contains source range information
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
