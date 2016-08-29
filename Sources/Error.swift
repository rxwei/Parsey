//
//  Error.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

public enum ParseError : Error {

    case error(at: ParserInput)
    case expecting(CustomStringConvertible, at: ParserInput)

}

extension ParseError : CustomStringConvertible {

    public var description: String {
        switch self {
            case let .error(at: input):
                return "Parse error ---- \(input)"
            case let .expecting(desc, at: input):
                let first = input.first
                return "Parse error ---- \(input)\n\nExpecting \(desc), but found \"\(first?.description ?? "")\""
        }
    }

    public var localizedDescription: String {
        return description
    }

}
