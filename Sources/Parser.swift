//
//  Parser.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

public struct ParserInput {

    public typealias Location = (line: Int, column: Int)
    public let stream: String.CharacterView
    public let location: Location

    public var isEmpty: Bool {
        return stream.isEmpty
    }

    public var first: Character? {
        return stream.first
    }

    public var text: String {
        return String(stream)
    }
    
    public init(_ string: String, at location: Location = (1, 0)) {
        self.stream = string.characters
        self.location = location
    }

    public init<S: Sequence>(_ stream: S, at location: Location = (1, 0)) where S.Iterator.Element == Character {
        self.stream = String.CharacterView(stream)
        self.location = location
    }

    public init(_ stream: String.CharacterView, at location: Location = (1, 0)) {
        self.stream = stream
        self.location = location
    }

    public init(emptyStreamAt location: Location = (1, 0)) {
        self.stream = String.CharacterView()
        self.location = location
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
        let newLoc = first == "\n"
                   ? (line: location.line + 1, column: 0)
                   : (line: location.line, column: location.column + 1)
        return ParserInput(stream.dropFirst(), at: newLoc)
    }

    public func dropFirst(_ n: Int) -> ParserInput {
        let prefix = stream.prefix(n)
        let newLoc = prefix.reduce(location) { loc, x in
            x == "\n" ? (loc.line + 1, 0) : (loc.line, loc.column + 1)
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
        return "(line \(location.line), column \(location.column)):\n\(streamPrint)"
    }
    
}

public struct Parser<Output> {

    public typealias Error = ParseError

    public typealias Input = ParserInput

    public var run: (Input) throws -> (Output, rest: Input)

    public init(run: @escaping (Input) throws -> (Output, rest: Input)) {
        self.run = run
    }

    public init(success output: Output) {
        self.init { input in (output, rest: ParserInput(emptyStreamAt: input.location)) }
    }

    public init(failure error: ParseError) {
        self.init { _ in throw error }
    }

    public func parse(_ input: String) throws -> Output {
        return try parse(ParserInput(input))
    }
    
    public func parse(_ input: Input) throws -> Output {
        do {
            let (output, rest) = try run(input)
            guard rest.isEmpty else { throw ParseError.error(at: rest) }
            return output
        }
    }

    public func or(_ other: @autoclosure @escaping () -> Parser<Output>) -> Parser<Output> {
        return Parser { input in
            do {
                return try self.run(input)
            }
            catch _ as ParseError {
                return try other().run(input)
            }
        }
    }

    public static func |(_ lhs: Parser<Output>,
                         _ rhs: @autoclosure @escaping () -> Parser<Output>) -> Parser<Output> {
        return Parser { input in
            do {
                return try lhs.run(input)
            }
            catch _ as ParseError {
                return try rhs().run(input)
            }
        }
    }


}

extension Parser : FlatMappable {

    public typealias MapSource = Output
    public typealias MapTarget = Any
    public typealias MapResult = Parser<MapTarget>
    public typealias ApplicativeTransform = Parser<(MapSource) -> MapTarget>

    public static func singleton(_ element: Output) -> Parser<Output> {
        return Parser { input in (element, input) }
    }

    public func map<MapTarget>(_ transform: @escaping (Output) -> MapTarget) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let (output, rest) = try self.run(input)
            return (transform(output), rest)
        }
    }

    public func apply<MapTarget>(_ transform: Parser<(Output) -> MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let (out1, rest1) = try transform.run(input)
            let (out2, rest2) = try self.run(rest1)
            return (out1(out2), rest2)
        }
    }

   public func flatMap<MapTarget>(_ transform: @escaping (Output) -> Parser<MapTarget>) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let (out, rest) = try self.run(input)
            return try transform(out).run(rest)
        }
    }

}
