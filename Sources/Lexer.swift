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
                throw ParseError.expecting(char, at: input)
            }
            return Parse(target: String(char), range: input.location..<input.location.advanced(), rest: input.dropFirst())
        }
    }

    public static func anyCharacter(in range: ClosedRange<Character>) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, range.contains(first) else {
                throw ParseError.expecting("a character within range \(range)", at: input)
            }
            return Parse(target: String(first), range: input.location..<input.location.advanced(), rest: input.dropFirst())
        }
    }

    public static func anyCharacter<S: Sequence>(in characters: S) -> Parser<String>
        where S.Iterator.Element == Character
    {
        return Parser { input in
            guard let first = input.first, characters.contains(first) else {
                throw ParseError.expecting("a character within {\(characters.map{"\"\($0)\""}.joined(separator: ", "))}", at: input)
            }
            return Parse(target: String(first), range: input.location..<input.location.advanced(), rest: input.dropFirst())
        }
    }

    public static func anyCharacter(in characterString: String) -> Parser<String> {
        return anyCharacter(in: characterString.characters)
    }

    public static func anyCharacter(except exception: Character) -> Parser<String> {
        return Parser { input in
            guard let first = input.first, first != exception else {
                throw ParseError.expecting("any character except \"\(exception)\"", at: input)
            }
            return Parse(target: String(first), range: input.location..<input.location.advanced(), rest: input.dropFirst())
        }
    }

    public static func anyCharacter<S: Sequence>(except exceptions: S) -> Parser<String>
        where S.Iterator.Element == Character
    {
        return Parser { input in
            guard let first = input.first, !exceptions.contains(first) else {
                throw ParseError.expecting("any character except {\(exceptions.map{"\"\($0)\""}.joined(separator: ", "))}", at: input)
            }
            return Parse(target: String(first), range: input.location..<input.location.advanced(), rest: input.dropFirst())
        }
    }

}

/// MARK: - Primitives
public extension Lexer {

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

    public static func string<S: Sequence>(until exception: S) -> Parser<String> where S.Iterator.Element == Character {
        return anyCharacter(except: exception).manyConcatenated()
    }

    public static func string(until character: Character) -> Parser<String> {
        return anyCharacter(except: character).manyConcatenated()
    }

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
                throw ParseError.expecting("Pattern \"\(pattern)\"", at: input)
            }
            let length = match.range.length
            return Parse(target: String(input.prefix(length)),
                         range: input.location..<input.location.advanced(byColumns: length),
                         rest: input.dropFirst(length))
        }
    }

    public static func string(_ string: String) -> Parser<String> {
        return Parser<String> { input in
            guard input.starts(with: string.characters) else {
                throw ParseError.expecting(string, at: input)
            }
            return Parse(target: string,
                         range: input.location..<input.location.advanced(byColumns: string.characters.count),
                         rest: input.dropFirst(string.characters.count))
        }
    }

}
