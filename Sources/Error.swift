//
//  Error.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

protocol ParseError : Error, CustomStringConvertible {
    var expected: String { get }
    var input: ParserInput { get }
}

public struct ParseFailure : ParseError {
    public var expected: String
    public var input: ParserInput
    internal var irrecoverable: Bool = false

    public init(expected: String, input: ParserInput) {
        self.expected = expected
        self.input = input
    }

    public init(extraInputAt input: ParserInput) {
        self.expected = "end of input"
        self.input = input
    }
}

public struct AccumulatedParseFailure : Error {
    
}

extension ParseFailure : CustomStringConvertible {
    public var description: String {
        let first = input.first
        return "Parse failure at \(input)\n\nExpecting \(expected), but found \"\(first?.description ?? "")\""
    }

    public var localizedDescription: String {
        return description
    }
}

