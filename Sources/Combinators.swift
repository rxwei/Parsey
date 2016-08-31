//
//  Combinators.swift
//  Parsey
//
//  Created by Richard Wei on 8/25/16.
//
//

import Funky

infix operator ~~> : FunctionCompositionPrecedence
infix operator <~~ : FunctionCompositionPrecedence
infix operator <*> : FunctionCompositionPrecedence
postfix operator +
postfix operator *

public extension Parser {

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
            catch {
                return Parse(target: targets, range: input.location..<endLoc, rest: lastRest)
            }
        }
    }
    
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
            catch {
                return Parse(target: (), range: input.location..<endLoc, rest: lastRest)
            }
        }
    }

    public func many() -> Parser<[Target]> {
        return flatMap { out in
            self.manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    public func skippedMany() -> Parser<()> {
        return self ~~> skippedManyOrNone()
    }

    public func withDefault(_ default: Target) -> Parser<Target> {
        return self | Parser(success: `default`)
    }

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

    public func between<Left, Right>(_ left: Parser<Left>,
                                     _ right: Parser<Right>) -> Parser<Target> {
        return left.flatMap { _ in
            self.flatMap { out in right.map { _ in out } }
        }
    }

    public func amid<T>(_ surrounding: Parser<T>) -> Parser<Target> {
        return between(surrounding, surrounding)
    }

    public func many<T>(separatedBy separator: Parser<T>) -> Parser<[Target]> {
        return flatMap { out in
            (separator ~~> self).manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    public func manyOrNone<T>(separatedBy separator: Parser<T>) -> Parser<[Target]> {
        return many(separatedBy: separator) | Parser<[Target]>(success: [])
    }

    public func ended<T>(by terminator: Parser<T>) -> Parser<Target> {
        return flatMap { res in terminator.map { _ in res } }
    }

    public func followed<T>(by follower: Parser<T>) -> Parser<T> {
        return flatMap { _ in follower }
    }

    public func skipped() -> Parser<()> {
        return map { _ in () }
    }

    public func optional() -> Parser<Target?> {
        return map{ x in x } | .return(nil)
    }
    
    public static func ~~><B>(_ lhs: Parser<Target>, _ rhs: Parser<B>) -> Parser<B> {
        return lhs.followed(by: rhs)
    }

    public static func <~~<B>(_ lhs: Parser<Target>, _ rhs: Parser<B>) -> Parser<Target> {
        return lhs.ended(by: rhs)
    }

    public static func <*><B>(_ lhs: Parser<(Target) -> B>, _ rhs: Parser<Target>) -> Parser<B> {
        return rhs.apply(lhs)
    }

}

public extension Parser where Target : Associative {

    public func maybeEmpty() -> Parser<Target> {
        return self | .return(Target.identity)
    }

    public func concatenatingResult(with next: Parser<Target>) -> Parser<Target> {
        return flatMap { out1 in
            next.map { out2 in
                out1 + out2
            }
        }
    }

    @inline(__always)
    public func manyConcatenated() -> Parser<Target> {
        return many().concatenated()
    }

    @inline(__always)
    public func manyConcatenatedOrNone() -> Parser<Target> {
        return manyOrNone().concatenated()
    }

    @inline(__always)
    public static func +(lhs: Parser<Target>,
                         rhs: Parser<Target>) -> Parser<Target> {
        return lhs.concatenatingResult(with: rhs)
    }

    @inline(__always)
    public static postfix func +(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenated()
    }

    @inline(__always)
    public static postfix func *(parser: Parser<Target>) -> Parser<Target> {
        return parser.manyConcatenatedOrNone()
    }

}

public extension Parser where Target : Sequence, Target.Iterator.Element : Associative {

    public func concatenated() -> Parser<Target.Iterator.Element> {
        return map { x in x.reduced() }
    }

}

