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
    internal var tagged: Bool = false
    internal var irrecoverable: Bool = false

    public init(expected: String, input: ParserInput) {
        self.expected = expected
        self.input = input
    }

    public init(extraInput input: ParserInput) {
        self.expected = "end of input"
        self.input = input
    }

    internal mutating func tag(_ tag: String) {
        expected = tag
        tagged = true
    }
}

extension ParseFailure : CustomStringConvertible {
    public var description: String {
        let first = input.first
        return "Parse failure at \(input)\nExpecting \(expected), but found \"\(first?.description ?? "")\""
    }

    public var localizedDescription: String {
        return description
    }
}

