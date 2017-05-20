//
//  Parser.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

/// Range from a source location to another, for range tracking
public typealias SourceRange = CountableRange<SourceLocation>

/// Input with location tracking
public struct ParserInput {
    public var lineStream: String.CharacterView
    public var stream: String.CharacterView
    public var location: SourceLocation
}

public extension ParserInput {
    var line: String {
        return String(lineStream.prefix(while: !="\n"))
    }

    var restLine: String {
        return String(stream.prefix(while: !="\n"))
    }

    var restLineLength: Int {
        return String.CharacterView(stream.prefix(while: !="\n")).count
    }

    var lineLength: Int {
        return restLineLength + location.column - 1
    }

    var isEmpty: Bool {
        return stream.isEmpty
    }

    var first: Character? {
        return stream.first
    }

    var text: String {
        return String(stream)
    }

    init(_ string: String) {
        self.lineStream = string.characters
        self.stream = self.lineStream
        self.location = SourceLocation()
    }

    init<S: Sequence>(_ stream: S) where S.Element == Character {
        self.lineStream = String.CharacterView(stream)
        self.stream = self.lineStream
        self.location = SourceLocation()
    }

    internal init(stream: String.CharacterView, lineStream: String.CharacterView,
                  location: SourceLocation = SourceLocation()) {
        self.lineStream = lineStream
        self.stream = stream
        self.location = location
    }

    internal init() {
        self.lineStream = String.CharacterView()
        self.stream = self.lineStream
        self.location = SourceLocation()
    }

}

extension ParserInput : Sequence {

    public func prefix(_ maxLength: Int) -> ParserInput {
        return ParserInput(
            stream: stream.prefix(maxLength),
            lineStream: lineStream,
            location: location
        )
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

    public func prefix(while predicate: (Character) throws -> Bool) rethrows -> ParserInput {
        var newLoc = location
        var newStream = String.CharacterView()
        for char in stream {
            guard try predicate(char) else { break }
            newStream.append(char)
            if char == "\n" {
                newLoc.advanceToNewLine()
            } else {
                newLoc.advance(by: 1)
            }
        }
        return ParserInput(
            stream: newStream,
            lineStream: newStream,
            location: newLoc
        )
    }

    public func drop(while predicate: (Character) throws -> Bool) rethrows -> ParserInput {
        var newLoc = location
        var newStream = stream
        var newLineStream = lineStream
        for char in stream {
            guard try predicate(char) else { break }
            newStream.removeFirst()
            if char == "\n" {
                newLineStream = newStream
                newLoc.advanceToNewLine()
            } else {
                newLoc.advance(by: 1)
            }
        }
        return ParserInput(
            stream: newStream,
            lineStream: newLineStream,
            location: newLoc
        )
    }

    public func dropFirst() -> ParserInput {
        guard let first = stream.first else { return self }
        if first == "\n" {
            let newStream = stream.dropFirst()
            return ParserInput(
                stream: newStream,
                lineStream: newStream,
                location: location.newLine()
            )
        }
        return ParserInput(
            stream: stream.dropFirst(),
            lineStream: lineStream,
            location: location.advanced(by: 1)
        )
    }

    public func dropFirst(_ n: Int) -> ParserInput {
        var newLoc = location
        var newStream = stream
        var newLineStream = lineStream
        for _ in 0..<n {
            guard !newStream.isEmpty else { break }
            let char = newStream.first
            newStream.removeFirst()
            if char == "\n" {
                newLineStream = newStream
                newLoc.advanceToNewLine()
            } else {
                newLoc.advance(by: 1)
            }
        }
        return ParserInput(
            stream: newStream,
            lineStream: newLineStream,
            location: newLoc
        )
    }

    public func dropLast() -> ParserInput {
        return ParserInput(stream: stream, lineStream: stream.dropLast(), location: location)
    }

    public func dropLast(_ n: Int) -> ParserInput {
        return ParserInput(stream: stream, lineStream: stream.dropLast(n), location: location)
    }

    /// TODO: Need location tracking!
    /// It does not matter to the parser since it's never used
    public func split(maxSplits: Int, omittingEmptySubsequences: Bool,
                      whereSeparator isSeparator: (Character) throws -> Bool) rethrows -> [ParserInput] {
        return try stream.split(maxSplits: maxSplits,
                                omittingEmptySubsequences: omittingEmptySubsequences,
                                whereSeparator: isSeparator).map { sub in ParserInput(sub) }
    }

}

extension ParserInput : CustomStringConvertible {

    public var description: String {
        let prefixLength = location.column - 1
        var locator = String(repeating: " ", count: prefixLength)
        locator.append("^")
        if restLineLength != 0 {
            for _ in 1..<restLineLength { locator.append("~") }
        }
        return "\(location):\n\(line)\n\(locator)"
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

    public static func success(_ target: Target) -> Parser<Target> {
        return Parser(success: target)
    }

    public static func failure(_ failure: ParseFailure) -> Parser<Target> {
        return Parser(failure: failure)
    }

    /// Parse a string
    public func parse(_ input: String) throws -> Target {
        return try parse(ParserInput(input))
    }

    private func parse(_ input: Input) throws -> Target {
        let output = try run(input)
        guard output.rest.isEmpty else { throw ParseFailure(input: output.rest) }
        return output.target
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

// MARK: - Mappable
extension Parser : Mappable {
    public typealias MapSource = Target
    public typealias MapTarget = Any
    public typealias MapResult = Parser<MapTarget>

    /// Transform the target to another
    public func map<MapTarget>(_ transform: (Target) throws -> MapTarget) rethrows -> Parser<MapTarget> {
        return withoutActuallyEscaping(transform) { f in
            Parser<MapTarget> { input in
                let out = try self.run(input)
                let newRange = input.location..<out.rest.location
                return Parse(target: try f(out.target), range: newRange, rest: out.rest)
            }
        }
    }
}

// MARK: - ApplicativeMappable
extension Parser : ApplicativeMappable {

    public typealias ApplicativeTransform = Parser<(Target) -> MapTarget>

    public static func singleton(_ element: Target) -> Parser<Target> {
        return Parser(success: element)
    }

    /// Apply the function result of a parser to the target
    public func apply<MapTarget>(_ transform: Parser<(Target) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out1 = try transform.run(input)
            let out2 = try self.run(out1.rest)
            let newRange = input.location..<out2.rest.location
            return Parse(target: out1.target(out2.target), range: newRange, rest: out2.rest)
        }
    }

}

// MARK: - FlatMappable
extension Parser : FlatMappable {

    public func flatMap<MapTarget>(_ transform: (Target) throws -> Parser<MapTarget>) rethrows -> Parser<MapTarget> {
        return withoutActuallyEscaping(transform) { f in
            Parser<MapTarget> { input in
                let out = try self.run(input)
                let out2 = try f(out.target).run(out.rest)
                let newRange = input.location..<out2.rest.location
                return Parse(target: out2.target, range: newRange, rest: out2.rest)
            }
        }
    }

    public func flatMap<MapTarget>(_ transform: (Target) -> MapTarget?) -> Parser<MapTarget> {
        return withoutActuallyEscaping(transform) { f in
            Parser<MapTarget> { input in
                let out = try self.run(input)
                guard let result = f(out.target) else {
                    throw ParseFailure(input: input)
                }
                return Parse(target: result, range: out.range, rest: out.rest)
            }
        }
    }

}

// MARK: - Range support
public extension Parser {

    func mapRange<MapTarget>(_ transform: @escaping (Target, SourceRange) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let newRange = input.location..<out.rest.location
            return Parse(target: transform(out.target, newRange), range: newRange, rest: out.rest)
        }
    }

    func applyRange<MapTarget>(_ transform: Parser<(Target, SourceRange) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out1 = try transform.run(input)
            let out2 = try self.run(out1.rest)
            let newRange = input.location..<out2.rest.location
            return Parse(target: out1.target(out2.target, newRange), range: newRange, rest: out2.rest)
        }
    }

    func flatMapRange<MapTarget>(_ transform: @escaping (Target, SourceRange) -> Parser<MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let out2 = try transform(out.target, out.range).run(out.rest)
            let newRange = input.location..<out2.rest.location
            return Parse(target: out2.target, range: newRange, rest: out2.rest)
        }
    }

    /// Transform the parse to another
    /// The parse (not parser!) contains source range information
    func mapParse<MapTarget>(_ transform: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let newRange = input.location..<out.rest.location
            return Parse(target: transform(out), range: newRange, rest: out.rest)
        }
    }

    /// Apply the function result of a parser to the target
    /// The parse (not parser!) contains source range information
    func applyParse<MapTarget>(_ transform: Parser<(Parse<Target>) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out1 = try transform.run(input)
            let out2 = try self.run(out1.rest)
            let newRange = input.location..<out2.rest.location
            return Parse(target: out1.target(out2), range: newRange, rest: out2.rest)
        }
    }

    func flatMapParse<MapTarget>(_ transform: @escaping (Parse<Target>) -> Parser<MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let out = try self.run(input)
            let out2 = try transform(out).run(out.rest)
            let newRange = input.location..<out2.rest.location
            return Parse(target: out2.target, range: newRange, rest: out2.rest)
        }
    }

}
