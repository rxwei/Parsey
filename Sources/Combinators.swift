//
//  Combinators.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

infix operator ~~>  : FunctionCompositionPrecedence /// .skipped(to:)
infix operator !~~> : FunctionCompositionPrecedence /// .nonbacktracking().skipped(to:)
infix operator <~~  : FunctionCompositionPrecedence /// .ended(by:)
infix operator !<~~ : FunctionCompositionPrecedence /// .nonbacktracking().ended(by:)
infix operator ~~   : FunctionCompositionPrecedence /// Left and right forming a tuple
infix operator !~~  : FunctionCompositionPrecedence /// Non-backtracking ~~
infix operator **   : FunctionCompositionPrecedence /// Apply lhs's result function to rhs's result
infix operator !**  : FunctionCompositionPrecedence /// Non-backtracking !**
infix operator ^^   : FunctionCompositionPrecedence /// .map(_:)
infix operator ^^^  : FunctionCompositionPrecedence /// .mapParse(_:)
infix operator !^^  : FunctionCompositionPrecedence /// .nonbacktracking().map(_:)
infix operator !^^^ : FunctionCompositionPrecedence /// .nonbacktracking().mapParse(_:)
infix operator <!-- : FunctionCompositionPrecedence /// .tagged(_:)
infix operator ..   : FunctionCompositionPrecedence /// .tagged(_:)

postfix operator .! /// Non-backtracking
postfix operator .? /// Optional
postfix operator .+ /// One or more
postfix operator .* /// Zero or more
postfix operator +  /// One or more concatenated
postfix operator *  /// Zero or more concatenated

public extension Parser {

    /// Disable backtracking so that it won't pass the `or` operator if it fails
    /// Equivalent to `.!` operator
    /// - returns: same parser with backtracking disabled
    public func nonbacktracking() -> Parser<Target> {
        return Parser { input in
            do {
                return try self.run(input)
            }
            catch var failure as ParseFailure where !failure.irrecoverable {
                failure.irrecoverable = true
                throw failure
            }
        }
    }

    /// Disable backtracking
    /// Same as `.nonbacktracking()`
    public static postfix func .!(parser: Parser<Target>) -> Parser<Target> {
        return parser.nonbacktracking()
    }

    /// Tag with description for clear error messages
    /// Equivalent to `<!--` operator
    /// - parameter tag: tag string
    /// - returns: the tagged parser
    @inline(__always)
    public func tagged(_ tag: String) -> Parser<Target> {
        return Parser { input in
            do {
                return try self.run(input)
            }
            catch var failure as ParseFailure {
                failure.expected = tag
                throw failure
            }
        }
    }

    /// Tag with description for clear error messages
    /// Equivalent to `.tagged(_:)`
    /// - returns: the tagged parser
    @available(*, renamed: "..")
    @inline(__always)
    public static func <!--(lhs: Parser<Target>, rhs: String) -> Parser<Target> {
        return lhs.tagged(rhs)
    }

    /// Tag with description for clear error messages
    /// Equivalent to `.tagged(_:)`
    /// - returns: the tagged parser
    @inline(__always)
    public static func ..(lhs: Parser<Target>, rhs: String) -> Parser<Target> {
        return lhs.tagged(rhs)
    }

    /// Accept input zero or more times
    /// - returns: the composed parser
    public func manyOrNone() -> Parser<[Target]> {
        return Parser<[Target]> { input in
            var targets: [Target] = []
            var lastRest = input
            var endLoc = input.location
            do {
                repeat {
                    let out = try self.run(lastRest)
                    targets.append(out.target)
                    lastRest = out.rest
                    endLoc = out.range.upperBound
                } while true
            }
            catch let failure as ParseFailure where !failure.irrecoverable {
                return Parse(target: targets, range: input.location..<endLoc, rest: lastRest)
            }
        }
    }
    
    /// Skipped zero or more times without output
    /// - returns: the composed parser without output
    public func skippedManyOrNone() -> Parser<()> {
        return Parser<()> { input in
            var lastRest = input
            var endLoc = input.location
            do {
                repeat {
                    let out = try self.run(lastRest)
                    lastRest = out.rest
                    endLoc = out.range.upperBound
                } while true
            }
            catch let failure as ParseFailure where !failure.irrecoverable {
                return Parse(target: (), range: input.location..<endLoc, rest: lastRest)
            }
        }
    }

    /// Accept input one or more times
    /// - returns: the composed parser
    public func many() -> Parser<[Target]> {
        return flatMap { out in
            self.manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    /// Skipped one or more times without output
    /// - returns: the composed parser without output
    public func skippedMany() -> Parser<()> {
        return self ~~> skippedManyOrNone()
    }

    /// With alternative parse result on failure
    /// - parameter default: alternative target
    /// - returns: the composed parser
    public func withDefault(_ default: Target) -> Parser<Target> {
        return self | Parser(success: `default`)
    }

    /// Occuring exactly a number of times
    /// - parameter times: number of times
    /// - returns: the composed parser
    public func occurring(_ times: Int) -> Parser<[Target]> {
        return Parser<[Target]> { input in
            var targets: [Target] = []
            var lastRest = input
            var endLoc = input.location
            for _ in 1...times {
                let out = try self.run(lastRest)
                lastRest = out.rest
                endLoc = out.range.upperBound
                targets.append(out.target)
            }
            return Parse(target: targets, range: input.location..<endLoc, rest: lastRest)
        }
    }

    /// In between of left and right
    /// Use this to parse `<left> <target> <right>`
    /// - parameter left: parser of the left side
    /// - parameter left: parser of the right side
    /// - returns: the composed parser
    public func between<Left, Right>(_ left: Parser<Left>,
                                     _ right: Parser<Right>) -> Parser<Target> {
        return left.flatMap { _ in
            self.flatMap { out in right.map { _ in out } }
        }
    }

    /// In between of surroundings
    /// Equivalent to `.between(surrounding, surrounding)`
    /// - parameter surrounding: parser of the surrounding
    /// - returns: the composed parser
    @inline(__always)
    public func amid<T>(_ surrounding: Parser<T>) -> Parser<Target> {
        return between(surrounding, surrounding)
    }

    /// Accept input one or more times, separated by some separator
    /// - parameter separator: parser of a separater
    /// - returns: the composed parser
    public func many<T>(separatedBy separator: Parser<T>) -> Parser<[Target]> {
        return flatMap { out in
            separator.skipped(to: self).manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    /// Accept input zero or more times, separated by some separator
    /// - parameter separator: parser of a separater
    /// - returns: the composed parser
    public func manyOrNone<T>(separatedBy separator: Parser<T>) -> Parser<[Target]> {
        return many(separatedBy: separator) | Parser<[Target]>(success: [])
    }

    /// Suffix operation parser
    /// Use this to avoid left-recursion!
    /// `a.suffixed(by: <s>)` produces a left-associative parse tree
    ///     (<s> (<s> (<s> (<s> a))))
    /// Use this to construct parsers for dot-expressions like `expr.f().g().z()`
    /// - parameter suffix: suffix parser that produces a 1-place function
    /// - returns: the composed parser
    public func suffixed(by suffix: Parser<(Target) -> Target>) -> Parser<Target> {
        func rest(_ x: Target) -> Parser<Target> {
            return suffix.flatMap { f in rest(f(x)) } | .return(x)
        }
        return flatMap(rest)
    }

    /// Left-associative infix operation parser
    /// Use this to avoid left-recursion!
    /// `a.infixedRight(by: op)` produces a left-associative parse tree
    ///     (<op> (<op> (<op> (<a> <op> <a>) <a>) <a>) <a>) 
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    public func infixedLeft(by op: Parser<(Target, Target) -> Target>) -> Parser<Target> {
        func rest(_ x: Target) -> Parser<Target> {
            return op.flatMap { f in self.flatMap { y in rest(f(x, y)) } } | .return(x)
        }
        return flatMap(rest)
    }

    /// Right-associative infix operation parser
    /// `a.infixedRight(by: op)` produces a right-associative parse tree
    ///     ((((<a> <op> <a>) <op> <a>) <op> <a>) <op> <a>)
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    public func infixedRight(by op: Parser<(Target, Target) -> Target>) -> Parser<Target> {
        func scan() -> Parser<Target> {
            return flatMap(rest)
        }
        func rest(_ x: Target) -> Parser<Target> {
            return op.flatMap { f in scan().map { y in f(x, y) } } | .return(x)
        }
        return scan()
    }

    /// Parse the right side on success, producing the original (left) result.
    /// Equivalent to `<~~` operator
    /// - parameter terminator: the parser of the rest input
    /// - returns: the composed parser
    public func ended<T>(by terminator: Parser<T>) -> Parser<Target> {
        return flatMap { res in terminator.map { _ in res } }
    }

    /// Parse the right side on success, producing a tuple of results from
    /// the left and the right.
    /// Equivalent to `~~` operator.
    /// - parameter terminator: the parser of the rest input
    /// - returns: the composed parser
    public func followed<T>(by follower: Parser<T>) -> Parser<(Target, T)> {
        return flatMap { out1 in follower.map { out2 in (out1, out2) } }
    }

    /// Parse the right side on success, producing only the result from the right.
    /// Equivalent to `~~>` operator.
    /// - parameter follower: the parser of the rest input
    /// - returns: the composed parser
    @inline(__always)
    public func skipped<T>(to follower: Parser<T>) -> Parser<T> {
        return flatMap { _ in follower }
    }

    /// Drop the result
    /// - returns: same parser without output
    @inline(__always)
    public func skipped() -> Parser<()> {
        return map { _ in () }
    }

    /// Make optional
    /// - returns: the composed parser that accepts the original input or nothing
    @inline(__always)
    public func optional() -> Parser<Target?> {
        return map{$0} | .return(nil)
    }

    /// Parse the right side on success, producing only the result from the right.
    /// Same as `.skipped(to:)`
    /// - returns: the composed parser
    @inline(__always)
    public static func ~~> <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<T> {
        return lhs.skipped(to: rhs)
    }

    @inline(__always)
    public static func !~~> <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<T> {
        return lhs.nonbacktracking().skipped(to: rhs)
    }

    /// Parse the right side on success, producing the original (left) result.
    /// Same as `.ended(by:)`
    /// - returns: the composed parser
    @inline(__always)
    public static func <~~ <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<Target> {
        return lhs.ended(by: rhs)
    }

    @inline(__always)
    public static func !<~~ <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<Target> {
        return lhs.nonbacktracking().ended(by: rhs)
    }

    /// Parse the right side on success, producing a tuple of results from
    /// the left and the right.
    /// Same as `.followed(by:)`
    /// - returns: the composed parser
    @inline(__always)
    static public func ~~ <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<(Target, T)> {
        return lhs.followed(by: rhs)
    }
    
    @inline(__always)
    static public func !~~ <T>(_ lhs: Parser<Target>, _ rhs: Parser<T>) -> Parser<(Target, T)> {
        return lhs.nonbacktracking().followed(by: rhs)
    }

    /// Parse the right side on success, producing a tuple of results from
    /// the left and the right.
    /// Same as `.followed(by:)`
    /// - returns: the composed parser
    @inline(__always)
    public static func ** <MapTarget>(
        _ lhs: Parser<(Target) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.apply(lhs)
    }

    @inline(__always)
    public static func !** <MapTarget>(
        _ lhs: Parser<(Target) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.nonbacktracking().apply(lhs)
    }

    /// Transform the target to the desired data structure
    /// Same as `.map(_:)`
    /// - returns: the composed parser
    @inline(__always)
    public static func ^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return lhs.map(rhs)
    }

    /// Transform the target to the desired data structure
    /// - returns: the composed parser
    @inline(__always)
    public static func ^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: MapTarget) -> Parser<MapTarget> {
        return lhs.map { _ in rhs }
    }

    /// Transform the parse to the desired data structure
    /// Same as `.mapParse(_:)`
    /// - returns: the composed parser
    @inline(__always)
    public static func ^^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return lhs.mapParse(rhs)
    }

    @inline(__always)
    public static func !^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().map(rhs)
    }

    @inline(__always)
    public static func !^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().map { _ in rhs }
    }

    @inline(__always)
    public static func !^^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().mapParse(rhs)
    }

    /// Same as `.optional()`
    @inline(__always)
    public static postfix func .? (_ parser: Parser<Target>) -> Parser<Target?> {
        return parser.optional()
    }

    /// Same as `.many()`
    @inline(__always)
    public static postfix func .+ (parser: Parser<Target>) -> Parser<[Target]> {
        return parser.many()
    }

    /// Same as `.manyOrNone()`
    @inline(__always)
    public static postfix func .* (parser: Parser<Target>) -> Parser<[Target]> {
        return parser.manyOrNone()
    }

}

/// When target is associative (i.e. monoid), a string for example,
/// this set of combinators are extremely useful.
public extension Parser where Target : Associative {

    /// Maybe empty
    /// - returns: the same parser but produces identity on failure
    public func maybeEmpty() -> Parser<Target> {
        return self | .return(Target.identity)
    }

    /// Concatenate the result with the other parser's
    /// - parameter next: parser of the right side
    /// - returns: the composed parser that produces concatenated result
    public func concatenatingResult(with next: Parser<Target>) -> Parser<Target> {
        return flatMap { out1 in next.map { out2 in out1 + out2 } }
    }

    /// Concatenate results one or more times
    /// Equivalent to `.many().concatenated()`
    /// - returns: the composed parser that produces concatenated result
    public func manyConcatenated() -> Parser<Target> {
        return many().concatenated()
    }

    /// Concatenate the result with the other parser's
    /// Equivalent to `.manyOrNone().concatenated()`
    /// - returns: the composed parser that produces concatenated result
    public func manyConcatenatedOrNone() -> Parser<Target> {
        return manyOrNone().concatenated()
    }

    /// Concatenate results zero or more times
    /// Same as `.concatenatingResult(with:)`
    /// - returns: the composed parser that produces concatenated result
    public static func +(lhs: Parser<Target>, rhs: Parser<Target>) -> Parser<Target> {
        return lhs.concatenatingResult(with: rhs)
    }

    /// Concatenate results one or more times
    /// Same as `.manyConcatenated()`
    /// - returns: the composed parser that produces concatenated result
    public static postfix func +(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenated()
    }

    /// Concatenate results zero or more times
    /// Same as `.manyConcatenatedOrNone()`
    /// - returns: the composed parser that produces concatenated result
    public static postfix func *(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenatedOrNone()
    }

}

public extension Parser where Target : Sequence, Target.Iterator.Element : Associative {

    public func concatenated() -> Parser<Target.Iterator.Element> {
        return map { $0.reduced() }
    }

}
