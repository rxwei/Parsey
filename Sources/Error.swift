//
//  Error.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

protocol ParseError : Error, CustomStringConvertible {
    var expected: String? { get }
    var input: ParserInput { get }
}

public struct ParseFailure : ParseError {
    public var expected: String?
    public var input: ParserInput
    internal var tagged: Bool = false
    internal var irrecoverable: Bool = false

    public init(expected: String, input: ParserInput) {
        self.expected = expected
        self.input = input
    }

    public init(input: ParserInput) {
        self.input = input
    }

    internal mutating func tag(_ tag: String) {
        expected = tag
        tagged = true
    }
}

extension ParseFailure : CustomStringConvertible {
    public var description: String {
        var prefix = input.restLine
        if prefix.count > 10 {
            prefix = String(prefix.prefix(10)) + " ..."
        }
        var desc = "Parse failure at \(input)"
        if let expected = expected {
            desc += "\nExpecting \(expected)"
            if !prefix.isEmpty {
                desc += ", but I found \"\(prefix)\""
            }
        }
        return desc
    }

    public var localizedDescription: String {
        return description
    }
}

