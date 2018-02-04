//
//  Lexer.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

internal extension Parse {
    init(input: ParserInput, target: Target, length: Int) {
        self.rest = input.dropFirst(length)
        self.range = input.location..<rest.location
        self.target = target
    }
}

public enum Lexer {}

/// TODO: Remove duplicate code in here
public extension Lexer {

    static func character(_ char: Character) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, first == char else {
                throw ParseFailure(expected: String(char), input: input)
            }
            return Parse(input: input, target: String(first), length: 1)
        }
    }

    static func anyCharacter(in range: ClosedRange<Character>) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, range.contains(first) else {
                throw ParseFailure(expected: "a character within range \(range)", input: input)
            }
            return Parse(input: input, target: String(first), length: 1)
        }
    }

    static func anyCharacter<S: Sequence>(in characters: S) -> Parser<String>
        where S.Element == Character
    {
        return Parser { input in
            guard let first = input.first, characters.contains(first) else {
                throw ParseFailure(
                    expected: "a character within {\(characters.map{"\"\($0)\""}.joined(separator: ", "))}",
                    input: input
                )
            }
            return Parse(input: input, target: String(first), length: 1)
        }
    }

    static func anyCharacter(in characterString: String) -> Parser<String> {
        return anyCharacter(in: characterString[characterString.startIndex ..< characterString.endIndex])
    }

    static func anyCharacter(except exception: Character) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, first != exception else {
                throw ParseFailure(expected: "any character except \"\(exception)\"", input: input)
            }
            return Parse(input: input, target: String(first), length: 1)
        }
    }

    static func anyCharacter<S: Sequence>(except exceptions: S) -> Parser<String>
        where S.Element == Character
    {
        return Parser { input in
            guard let first = input.first, !exceptions.contains(first) else {
                throw ParseFailure(
                    expected: "any character except {\(exceptions.map{"\"\($0)\""}.joined(separator: ", "))}",
                    input: input
                )
            }
            return Parse(input: input, target: String(first), length: 1)
        }
    }

}

/// MARK: - Primitives
public extension Lexer {

    static let space           = character(" ")
    static let tab             = character("\t")

    static let whitespace      = anyCharacter(in: [" ", "\t"])
    static let whitespaces     = whitespace+
    
    static let newLine         = anyCharacter(in: ["\n", "\r"])
    static let newLines        = newLine+
    
    static let upperLetter     = anyCharacter(in: "A"..."Z")
    static let lowerLetter     = anyCharacter(in: "a"..."z")
    static let letter          = upperLetter | lowerLetter

    static let digit           = anyCharacter(in: "0"..."9")
    static let unsignedInteger = digit.manyConcatenated()
    static let unsignedDecimal = unsignedInteger + character(".") + unsignedInteger
    static let signedInteger   = anyCharacter(in: "+-").maybeEmpty() + unsignedInteger
    static let signedDecimal   = anyCharacter(in: "+-").maybeEmpty() + unsignedDecimal

    static let end = Parser<String> { input in
        guard input.isEmpty else {
            throw ParseFailure(input: input)
        }
        return Parse(target: "", range: input.location..<input.location, rest: input)
    }

}

import Foundation

/// MARK: - String Matching
public extension Lexer {

    /// Parse a string until it sees a character in the exception list,
    /// without consuming the character
    static func string<S: Sequence>(until exception: S) -> Parser<String>
        where S.Element == Character {
        return anyCharacter(except: exception).manyConcatenated()
    }

    /// Parse a string until it sees a the exception character, 
    /// without consuming the character
    static func string(until character: Character) -> Parser<String> {
        return anyCharacter(except: character).manyConcatenated()
    }

    /// Match regular expression
    static func regex(_ pattern: String) -> Parser<String> {
        return Parser<String> { input in
            #if !os(macOS) && !swift(>=3.1) /// Swift standard library inconsistency!
            let regex = try RegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
            #else
            let regex = try NSRegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
            #endif
            let text = input.text
            let matches = regex.matches(
                in: text,
                options: [ .anchored ],
                range: NSMakeRange(0, input.stream.count)
            )
            guard let match = matches.first else {
                throw ParseFailure(expected: "pattern \"\(pattern)\"", input: input)
            }
            /// UTF16 conversion is safe here since NSRegularExpression results are based on UTF16
            let matchedText = String(text.utf16.prefix(match.range.length))!
            return Parse(input: input, target: matchedText, length: matchedText.count)
        }
    }

    /// Match any token in the collection
    /// - Note: Since this is based on regular expression matching, you should be careful
    /// with special regex characters
    static func token<C: Collection>(in tokens: C) -> Parser<String>
        where C.Element == String {
        return regex(tokens.joined(separator: "|"))
    }

    /// Parse an explicit token
    static func token(_ token: String) -> Parser<String> {
        return Parser<String> { input in
            guard input.starts(with: token) else {
                throw ParseFailure(expected: "token \"\(token)\"", input: input)
            }
            return Parse(input: input, target: token, length: token.count)
        }
    }

}

/// MARK: - Combinator extension on strings
public extension Parser {

    func amid(_ surrounding: String) -> Parser<Target> {
        return amid(Lexer.token(surrounding))
    }

    func between(_ left: String, _ right: String) -> Parser<Target> {
        return between(Lexer.token(left), Lexer.token(right))
    }

    static func ~~>(_ lhs: String, _ rhs: Parser<Target>) -> Parser<Target> {
        return Lexer.token(lhs) ~~> rhs
    }

    static func !~~>(_ lhs: String, _ rhs: Parser<Target>) -> Parser<Target> {
        return Lexer.token(lhs) !~~> rhs
    }

    static func <~~(_ lhs: Parser<Target>, _ rhs: String) -> Parser<Target> {
        return lhs <~~ Lexer.token(rhs)
    }

    static func !<~~(_ lhs: Parser<Target>, _ rhs: String) -> Parser<Target> {
        return lhs !<~~ Lexer.token(rhs)
    }

}
