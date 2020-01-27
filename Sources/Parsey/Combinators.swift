//
//  Combinators.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

infix operator ~~>  : FunctionCompositionPrecedence   /// .skipped(to:)
infix operator !~~> : FunctionCompositionPrecedence   /// .nonbacktracking().skipped(to:)
infix operator <~~  : FunctionCompositionPrecedence   /// .ended(by:)
infix operator !<~~ : FunctionCompositionPrecedence   /// .nonbacktracking().ended(by:)
infix operator ~~   : FunctionCompositionPrecedence   /// Left and right forming a tuple
infix operator !~~  : FunctionCompositionPrecedence   /// Non-backtracking ~~
infix operator **   : FunctionCompositionPrecedence   /// Apply lhs's result function to rhs's result
infix operator !**  : FunctionCompositionPrecedence   /// Non-backtracking !**
infix operator ^^=  : FunctionCompositionPrecedence   /// .map { _ in ... }
infix operator ^^   : FunctionCompositionPrecedence   /// .map(_:)
infix operator ^^^  : FunctionCompositionPrecedence   /// .mapRange(_:) 
infix operator ^^&  : FunctionCompositionPrecedence   /// .mapParse(_:)
infix operator !^^  : FunctionCompositionPrecedence   /// .nonbacktracking().map(_:)
infix operator !^^=  : FunctionCompositionPrecedence  /// .nonbacktracking().map { _ in ... }
infix operator !^^^ : FunctionCompositionPrecedence   /// .nonbacktracking().mapRange(_:)
infix operator !^^& : FunctionCompositionPrecedence   /// .nonbacktracking().mapParse(_:)
infix operator <!-- : FunctionCompositionPrecedence   /// .tagged(_:)
infix operator ..   : FunctionCompositionPrecedence   /// .tagged(_:)

postfix operator .! /// Non-backtracking
postfix operator .? /// Optional
postfix operator .+ /// One or more
postfix operator .* /// Zero or more
postfix operator +  /// One or more concatenated
postfix operator *  /// Zero or more concatenated
postfix operator .^

public extension Parser {

    /// Disable backtracking so that it won't pass the `or` operator if it fails
    /// Equivalent to `.!` operator
    /// - returns: same parser with backtracking disabled
    func nonbacktracking() -> Parser<Target> {
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
    static postfix func .!(parser: Parser<Target>) -> Parser<Target> {
        return parser.nonbacktracking()
    }

    /// Tag with description for clear error messages
    /// Equivalent to `..` operator
    /// - parameter tag: tag string
    /// - returns: the tagged parser
    func tagged(_ tag: String) -> Parser<Target> {
        return Parser { input in
            do {
                return try self.run(input)
            }
            catch var failure as ParseFailure where !failure.tagged {
                failure.tag(tag)
                throw failure
            }
        }
    }

    func satisfying(_ predicate: @escaping (Target) -> Bool) -> Parser<Target> {
        return Parser { input in
            let out = try self.run(input)
            guard predicate(out.target) else {
                throw ParseFailure(input: input)
            }
            return out
        }
    }

    /// Tag with description for clear error messages
    /// Equivalent to `.tagged(_:)`
    /// - returns: the tagged parser
    @available(*, renamed: "..")
    @inline(__always)
    static func <!--(lhs: Parser<Target>, rhs: String) -> Parser<Target> {
        return lhs.tagged(rhs)
    }

    /// Tag with description for clear error messages
    /// Equivalent to `.tagged(_:)`
    /// - returns: the tagged parser
    @inline(__always)
    static func ..(lhs: Parser<Target>, rhs: String) -> Parser<Target> {
        return lhs.tagged(rhs)
    }

    /// Accept input zero or more times
    /// - returns: the composed parser
    func manyOrNone() -> Parser<[Target]> {
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
    func skippedManyOrNone() -> Parser<()> {
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
    func many() -> Parser<[Target]> {
        return flatMap { out in
            self.manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    /// Skipped one or more times without output
    /// - returns: the composed parser without output
    func skippedMany() -> Parser<()> {
        return self ~~> self.skippedManyOrNone()
    }

    /// With alternative parse result on failure
    /// - parameter default: alternative target
    /// - returns: the composed parser
    func withDefault(_ default: Target) -> Parser<Target> {
        return self | Parser(success: `default`)
    }

    /// Occuring exactly a number of times
    /// - parameter times: number of times
    /// - returns: the composed parser
    func occurring(_ times: Int) -> Parser<[Target]> {
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
    func between<Left, Right>(_ left: Parser<Left>,
                        _ right: @autoclosure @escaping () -> Parser<Right>) -> Parser<Target> {
        return left.flatMap { _ in
            self.flatMap { out in right().map { _ in out } }
        }
    }

    /// In between of surroundings
    /// Equivalent to `.between(surrounding, surrounding)`
    /// - parameter surrounding: parser of the surrounding
    /// - returns: the composed parser
    func amid<T>(_ surrounding: Parser<T>) -> Parser<Target> {
        return surrounding.flatMap { _ in
            self.flatMap { out in surrounding.map { _ in out } }
        }
    }

    /// Accept input one or more times, separated by some separator
    /// - parameter separator: parser of a separater
    /// - returns: the composed parser
    func many<T>(separatedBy separator: @autoclosure @escaping () -> Parser<T>) -> Parser<[Target]> {
        return flatMap { out in
            separator().skipped(to: self).manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    /// Accept input one or more times, separated by some separator
    /// - parameter separator: separator
    /// - returns: the composed parser
    func many(separatedBy separator: String) -> Parser<[Target]> {
        return flatMap { out in
            Lexer.token(separator).skipped(to: self).manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    /// Accept input zero or more times, separated by some separator
    /// - parameter separator: parser of a separater
    /// - returns: the composed parser
    func manyOrNone<T>(separatedBy separator: @autoclosure @escaping () -> Parser<T>) -> Parser<[Target]> {
        return many(separatedBy: separator()) | Parser<[Target]>(success: [])
    }

    /// Accept input zero or more times, separated by some separator
    /// - parameter separator: parser of a separater
    /// - returns: the composed parser
    func manyOrNone(separatedBy separator: String) -> Parser<[Target]> {
        return many(separatedBy: Lexer.token(separator)) | Parser<[Target]>(success: [])
    }

    /// Suffix operation parser
    /// Use this to avoid left-recursion!
    /// `a.suffixed(by: <s>)` produces a left-associative parse tree
    ///     (<s> (<s> (<s> (<s> a))))
    /// Use this to construct parsers for dot-expressions like `expr.f().g().z()`
    /// - parameter suffix: suffix parser that produces a 1-place function
    /// - returns: the composed parser
    func suffixed(by suffix: @autoclosure @escaping () -> Parser<(Target) -> Target>) -> Parser<Target> {
        func rest(_ x: Target) -> Parser<Target> {
            return suffix().flatMap { f in rest(f(x)) } | .return(x)
        }
        return flatMap(rest)
    }

    /// Suffix operation parser
    /// Use this to avoid left-recursion!
    /// `a.suffixed(by: <s>)` produces a left-associative parse tree
    ///     (<s> (<s> (<s> (<s> a))))
    /// Use this to construct parsers for dot-expressions like `expr.f().g().z()`
    /// - parameter suffix: suffix parser that produces a 1-place function
    /// - returns: the composed parser
    func suffixed(by suffix: @autoclosure @escaping () -> Parser<(Target, SourceRange) -> Target>) -> Parser<Target> {
        func rest(_ x: Target, _ lhsRange: SourceRange) -> Parser<Target> {
            return suffix().flatMapRange { f, rhsRange in
                let range = lhsRange.lowerBound..<rhsRange.upperBound
                return rest(f(x, range), range)
            } | .return(x)
        }
        return flatMapRange(rest)
    }

    /// Left-associative infix operation parser
    /// Use this to avoid left-recursion!
    /// `a.infixedRight(by: op)` produces a left-associative parse tree
    ///     (<op> (<op> (<op> (<a> <op> <a>) <a>) <a>) <a>)
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    func infixedLeft(by op: @autoclosure @escaping () -> Parser<(Target, Target) -> Target>) -> Parser<Target> {
        func rest(_ x: Target) -> Parser<Target> {
            return op().flatMap { f in self.flatMap { y in rest(f(x, y)) } } | .return(x)
        }
        return flatMap(rest)
    }

    /// Left-associative infix operation parser
    /// Use this to avoid left-recursion!
    /// `a.infixedRight(by: op)` produces a left-associative parse tree
    ///     (<op> (<op> (<op> (<a> <op> <a>) <a>) <a>) <a>)
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    func infixedLeft(by op: @autoclosure @escaping () -> Parser<(Target, Target, SourceRange) -> Target>) -> Parser<Target> {
        func rest(_ x: Target, _ lhsRange: SourceRange) -> Parser<Target> {
            return op().flatMap { f in
                self.flatMapRange { y, rhsRange in
                    let range = lhsRange.lowerBound..<rhsRange.upperBound
                    return rest(f(x, y, range), range)
                }
            } | .return(x)
        }
        return flatMapRange(rest)
    }

    /// Right-associative infix operation parser
    /// `a.infixedRight(by: op)` produces a right-associative parse tree
    ///     ((((<a> <op> <a>) <op> <a>) <op> <a>) <op> <a>)
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    func infixedRight(by op: @autoclosure @escaping () -> Parser<(Target, Target) -> Target>) -> Parser<Target> {
        func scan() -> Parser<Target> {
            return flatMap(rest)
        }
        func rest(_ x: Target) -> Parser<Target> {
            return op().flatMap { f in scan().map { y in f(x, y) } } | .return(x)
        }
        return scan()
    }

    /// Right-associative infix operation parser
    /// `a.infixedRight(by: op)` produces a right-associative parse tree
    ///     ((((<a> <op> <a>) <op> <a>) <op> <a>) <op> <a>)
    /// - parameter op: infix operator parser that produces a 2-place function
    /// - returns: the composed parser
    func infixedRight(by op: @autoclosure @escaping () -> Parser<(Target, Target, SourceRange) -> Target>) -> Parser<Target> {
        func scan() -> Parser<Target> {
            return flatMapRange(rest)
        }
        func rest(_ x: Target, _ lhsRange: SourceRange) -> Parser<Target> {
            return op().flatMap { f in
                scan().mapRange { y, rhsRange in
                    let range = lhsRange.lowerBound..<rhsRange.upperBound
                    return f(x, y, range)
                }
            } | .return(x)
        }
        return scan()
    }

    /// Parse the right side on success, producing the original (left) result.
    /// Equivalent to `<~~` operator
    /// - parameter terminator: the parser of the rest input
    /// - returns: the composed parser
    func ended<T>(by terminator: @autoclosure @escaping () -> Parser<T>) -> Parser<Target> {
        return flatMap { res in terminator().map { _ in res } }
    }

    /// Parse the right side on success, producing a tuple of results from
    /// the left and the right.
    /// Equivalent to `~~` operator.
    /// - parameter terminator: the parser of the rest input
    /// - returns: the composed parser
    func followed<T>(by follower: @autoclosure @escaping () -> Parser<T>) -> Parser<(Target, T)> {
        return flatMap { out1 in follower().map { out2 in (out1, out2) } }
    }

    /// Parse the right side on success, producing only the result from the right.
    /// Equivalent to `~~>` operator.
    /// - parameter follower: the parser of the rest input
    /// - returns: the composed parser
    @inline(__always)
    func skipped<T>(to follower: @autoclosure @escaping () -> Parser<T>) -> Parser<T> {
        return flatMap { _ in follower() }
    }

    /// Drop the result
    /// - returns: same parser without output
    @inline(__always)
    func skipped() -> Parser<()> {
        return map { _ in () }
    }

    /// Make optional
    /// - returns: the composed parser that accepts the original input or nothing
    func optional() -> Parser<Target?> {
        return map{$0} | .return(nil)
    }

    /// Parse the right side on success, producing only the result from the right.
    /// Same as `.skipped(to:)`
    /// - returns: the composed parser
    @inline(__always)
    static func ~~> <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<T> {
        return lhs.skipped(to: rhs())
    }

    @inline(__always)
    static func !~~> <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<T> {
        return lhs.nonbacktracking().skipped(to: rhs())
    }

    /// Parse the right side on success, producing the original (left) result.
    /// Same as `.ended(by:)`
    /// - returns: the composed parser
    @inline(__always)
    static func <~~ <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<Target> {
        return lhs.ended(by: rhs())
    }

    @inline(__always)
    static func !<~~ <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<Target> {
        return lhs.nonbacktracking().ended(by: rhs())
    }

    /// Parse the right side on success, producing a tuple of results from
    /// the left and the right.
    /// Same as `.followed(by:)`
    /// - returns: the composed parser
    @inline(__always)
    static func ~~ <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<(Target, T)> {
        return lhs.followed(by: rhs())
    }

    /// Parse the right side on success without backtracking, producing a
    /// tuple of results from the left and the right.
    /// Same as `.followed(by:)`
    /// - returns: the composed parser
    @inline(__always)
    static func !~~ <T>(_ lhs: Parser<Target>, _ rhs: @autoclosure @escaping () -> Parser<T>) -> Parser<(Target, T)> {
        return lhs.nonbacktracking().followed(by: rhs())
    }

    @inline(__always)
    static func ** <MapTarget>(
        _ lhs: Parser<(Target) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.apply(lhs)
    }

    @inline(__always)
    static func !** <MapTarget>(
        _ lhs: Parser<(Target) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.nonbacktracking().apply(lhs)
    }

    /// Transform the target to the desired data structure
    /// Same as `.map(_:)`
    /// - returns: the composed parser
    @inline(__always)
    static func ^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return lhs.map(rhs)
    }

    /// Transform the target to the desired data structure
    /// - returns: the composed parser
    @inline(__always)
    static func ^^= <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: MapTarget) -> Parser<MapTarget> {
        return lhs.map { _ in rhs }
    }

    /// Transform the parse to the desired data structure
    /// Same as `.mapRange(_:)`
    /// - returns: the composed parser
    @inline(__always)
    static func ^^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target, SourceRange) -> MapTarget) -> Parser<MapTarget> {
        return lhs.mapRange(rhs)
    }

    @inline(__always)
    static func ** <MapTarget>(
        _ lhs: Parser<(Target, SourceRange) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.applyRange(lhs)
    }

    @inline(__always)
    static func ** <MapTarget>(
        _ lhs: Parser<(Target) -> (SourceRange) -> MapTarget>, _ rhs: Parser<Target>) -> Parser<MapTarget> {
        return rhs.applyRange(lhs.map(uncurry))
    }

    /// Transform the parse to the desired data structure
    /// Same as `.mapParse(_:)`
    /// - returns: the composed parser
    @inline(__always)
    static func ^^& <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return lhs.mapParse(rhs)
    }

    @inline(__always)
    static func !^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target) -> MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().map(rhs)
    }

    @inline(__always)
    static func !^^= <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().map { _ in rhs }
    }

    @inline(__always)
    static func !^^^ <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Target, SourceRange) -> MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().mapRange(rhs)
    }

    @inline(__always)
    static func !^^& <MapTarget>(
        _ lhs: Parser<Target>, _ rhs: @escaping (Parse<Target>) -> MapTarget) -> Parser<MapTarget> {
        return lhs.nonbacktracking().mapParse(rhs)
    }

    /// Same as `.optional()`
    @inline(__always)
    static postfix func .? (_ parser: Parser<Target>) -> Parser<Target?> {
        return parser.optional()
    }

    /// Same as `.many()`
    @inline(__always)
    static postfix func .+ (parser: Parser<Target>) -> Parser<[Target]> {
        return parser.many()
    }

    /// Same as `.manyOrNone()`
    @inline(__always)
    static postfix func .* (parser: Parser<Target>) -> Parser<[Target]> {
        return parser.manyOrNone()
    }

    @inline(__always)
    static postfix func .^ (parser: Parser<(SourceRange) -> Target>) -> Parser<Target> {
        return parser.mapRange { target, range in target(range) }
    }

}

/// When target is associative (i.e. monoid), a string for example,
/// this set of combinators are extremely useful.
public extension Parser where Target : Associable {

    /// Maybe empty
    /// - returns: the same parser but produces identity on failure
    func maybeEmpty() -> Parser<Target> {
        return self | .return(Target.identity)
    }

    /// Concatenate the result with the other parser's
    /// - parameter next: parser of the right side
    /// - returns: the composed parser that produces concatenated result
    func concatenatingResult(with next: @autoclosure @escaping () -> Parser<Target>) -> Parser<Target> {
        return flatMap { out1 in next().map { out2 in out1 + out2 } }
    }

    /// Concatenate results one or more times
    /// Equivalent to `.many().concatenated()`
    /// - returns: the composed parser that produces concatenated result
    func manyConcatenated() -> Parser<Target> {
        return many().concatenated()
    }

    /// Concatenate the result with the other parser's
    /// Equivalent to `.manyOrNone().concatenated()`
    /// - returns: the composed parser that produces concatenated result
    func manyConcatenatedOrNone() -> Parser<Target> {
        return manyOrNone().concatenated()
    }

    /// Concatenate results zero or more times
    /// Same as `.concatenatingResult(with:)`
    /// - returns: the composed parser that produces concatenated result
    static func +(lhs: Parser<Target>, rhs: @autoclosure @escaping () -> Parser<Target>) -> Parser<Target> {
        return lhs.concatenatingResult(with: rhs())
    }

    /// Concatenate results one or more times
    /// Same as `.manyConcatenated()`
    /// - returns: the composed parser that produces concatenated result
    static postfix func +(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenated()
    }

    /// Concatenate results zero or more times
    /// Same as `.manyConcatenatedOrNone()`
    /// - returns: the composed parser that produces concatenated result
    static postfix func *(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenatedOrNone()
    }

}

public extension Parser where Target : Hashable {
    func map<MapTarget>(_ mappings: [Target : MapTarget]) -> Parser<MapTarget> {
        return Parser<MapTarget> { input in
            let parse = try self.run(input)
            guard let target = mappings[parse.target] else {
                throw ParseFailure(expected: String(describing: mappings.keys),
                                   input: input)
            }
            return Parse(target: target, range: parse.range, rest: parse.rest)
        }
    }
}

public extension Parser where Target : Sequence & Reducible, Target.Element : Associable {
    func concatenated() -> Parser<Target.Element> {
        return map {
            $0.reduced()
        }
    }
}
