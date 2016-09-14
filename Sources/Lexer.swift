//
//  Lexer.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

public enum Lexer {

    public static func character(_ char: Character) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, first == char else {
                throw ParseFailure(expected: String(char), input: input)
            }
            return Parse(
                target: String(char),
                range: input.location..<input.location.advanced(past: first),
                rest: input.dropFirst()
            )
        }
    }

    public static func anyCharacter(in range: ClosedRange<Character>) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, range.contains(first) else {
                throw ParseFailure(expected: "a character within range \(range)", input: input)
            }
            return Parse(
                target: String(first),
                range: input.location..<input.location.advanced(past: first),
                rest: input.dropFirst()
            )
        }
    }

    public static func anyCharacter<S: Sequence>(in characters: S) -> Parser<String>
        where S.Iterator.Element == Character
    {
        return Parser { input in
            guard let first = input.first, characters.contains(first) else {
                throw ParseFailure(
                    expected: "a character within {\(characters.map{"\"\($0)\""}.joined(separator: ", "))}",
                    input: input
                )
            }
            return Parse(
                target: String(first),
                range: input.location..<input.location.advanced(past: first),
                rest: input.dropFirst()
            )
        }
    }

    public static func anyCharacter(in characterString: String) -> Parser<String> {
        return anyCharacter(in: characterString.characters)
    }

    public static func anyCharacter(except exception: Character) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, first != exception else {
                throw ParseFailure(expected: "any character except \"\(exception)\"", input: input)
            }
            return Parse(
                target: String(first),
                range: input.location..<input.location.advanced(past: first),
                rest: input.dropFirst()
            )
        }
    }

    public static func anyCharacter<S: Sequence>(except exceptions: S) -> Parser<String>
        where S.Iterator.Element == Character
    {
        return Parser { input in
            guard let first = input.first, !exceptions.contains(first) else {
                throw ParseFailure(
                    expected: "any character except {\(exceptions.map{"\"\($0)\""}.joined(separator: ", "))}",
                    input: input)
            }
            return Parse(
                target: String(first),
                range: input.location..<input.location.advanced(past: first),
                rest: input.dropFirst()
            )
        }
    }

}

/// MARK: - Primitives
public extension Lexer {

    public static let space           = character(" ")
    public static let tab             = character("\t")

    public static let whitespace      = anyCharacter(in: [" ", "\t"])
    public static let whitespaces     = whitespace+
    
    public static let newLine         = anyCharacter(in: ["\n", "\r"])
    public static let newLines        = newLine+
    
    public static let upperLetter     = anyCharacter(in: "A"..."Z")
    public static let lowerLetter     = anyCharacter(in: "a"..."z")
    public static let letter          = upperLetter | lowerLetter

    public static let digit           = anyCharacter(in: "0"..."9")
    public static let unsignedInteger = digit.manyConcatenated()
    public static let unsignedDecimal = unsignedInteger + character(".") + unsignedInteger
    public static let signedInteger   = anyCharacter(in: "+-").maybeEmpty() + unsignedInteger
    public static let signedDecimal   = anyCharacter(in: "+-").maybeEmpty() + unsignedDecimal

}

import Foundation

/// MARK: - String Matching
public extension Lexer {

    /// Parse a string until it sees a character in the exception list,
    /// without consuming the character
    public static func string<S: Sequence>(until exception: S) -> Parser<String>
        where S.Iterator.Element == Character {
        return anyCharacter(except: exception).manyConcatenated()
    }

    /// Parse a string until it sees a the exception character, 
    /// without consuming the character
    public static func string(until character: Character) -> Parser<String> {
        return anyCharacter(except: character).manyConcatenated()
    }

    /// Match regular expression
    public static func regex(_ pattern: String) -> Parser<String> {
        return Parser<String> { input in
            #if os(Linux)
            let regex = try RegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
            #else
            let regex = try NSRegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
            #endif
            let matches = regex.matches(in: input.text,
                                        options: [ .anchored ],
                                        range: NSMakeRange(0, input.stream.count))
            guard let match = matches.first else {
                throw ParseFailure(expected: "pattern \"\(pattern)\"", input: input)
            }
            let length = match.range.length
            let prefix = input.stream.prefix(length)
            return Parse(target: String(prefix),
                         range: input.location..<input.location.advanced(byScanning: prefix),
                         rest: input.dropFirst(length))
        }
    }

    /// Parse an explicit token
    public static func token(_ token: String) -> Parser<String> {
        return Parser<String> { input in
            guard input.starts(with: token.characters) else {
                throw ParseFailure(expected: "token \"\(token)\"", input: input)
            }
            return Parse(target: token,
                         range: input.location..<input.location.advanced(byScanning: token.characters),
                         rest: input.dropFirst(token.characters.count))
        }
    }

    @available(*, deprecated, message: "Use 'token(_:)' instead")
    public static func string(_ string: String) -> Parser<String> {
        return Parser<String> { input in
            guard input.starts(with: string.characters) else {
                throw ParseFailure(expected: "string \"\(string)\"", input: input)
            }
            return Parse(target: string,
                         range: input.location..<input.location.advanced(byScanning: string.characters),
                         rest: input.dropFirst(string.characters.count))
        }
    }

}

/// MARK: - Combinator extension on strings
public extension Parser {

    public func amid(_ surrounding: String) -> Parser<Target> {
        return amid(Lexer.token(surrounding))
    }

    public func between(_ left: String, _ right: String) -> Parser<Target> {
        return between(Lexer.token(left), Lexer.token(right))
    }

    public static func ~~>(_ lhs: String, _ rhs: Parser<Target>) -> Parser<Target> {
        return Lexer.token(lhs) ~~> rhs
    }

    public static func !~~>(_ lhs: String, _ rhs: Parser<Target>) -> Parser<Target> {
        return Lexer.token(lhs) !~~> rhs
    }

    public static func <~~(_ lhs: Parser<Target>, _ rhs: String) -> Parser<Target> {
        return lhs <~~ Lexer.token(rhs)
    }

    public static func !<~~(_ lhs: Parser<Target>, _ rhs: String) -> Parser<Target> {
        return lhs !<~~ Lexer.token(rhs)
    }

}
