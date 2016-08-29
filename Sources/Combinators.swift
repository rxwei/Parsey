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

    public func manyOrNone() -> Parser<[Output]> {
        return Parser<[Output]> { input in
            var output: [Output] = []
            var lastRest = input
            do {
                repeat {
                    let (out, rest) = try self.run(lastRest)
                    lastRest = rest
                    output.append(out)
                } while true
            }
            catch {
                return (output, lastRest)
            }
        }
    }
    
    public func skippedManyOrNone() -> Parser<()> {
        return Parser<()> { input in
            var lastRest = input
            do {
                repeat {
                    let (_, rest) = try self.run(lastRest)
                    lastRest = rest
                } while true
            }
            catch {
                return ((), lastRest)
            }
        }
    }

    public func many() -> Parser<[Output]> {
        return flatMap { out in
            self.manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    public func skippedMany() -> Parser<()> {
        return self ~~> skippedManyOrNone()
    }

    public func withDefault(_ default: Output) -> Parser<Output> {
        return self | .return(`default`)
    }

    public func occurring(_ times: Int) -> Parser<[Output]> {
        return Parser<[Output]> { input in
            var output: [Output] = []
            var lastRest = input
            for _ in 1...times {
                let (out, rest) = try self.run(lastRest)
                lastRest = rest
                output.append(out)
            }
            return (output, lastRest)
        }
    }

    public func between<Left, Right>(_ left: Parser<Left>,
                                     _ right: Parser<Right>) -> Parser<Output> {
        return left.flatMap { _ in
            self.flatMap { out in right.map { _ in out } }
        }
    }

    public func amid<T>(_ surrounding: Parser<T>) -> Parser<Output> {
        return between(surrounding, surrounding)
    }

    public func many<T>(separatedBy separator: Parser<T>) -> Parser<[Output]> {
        return flatMap { out in
            (separator ~~> self).manyOrNone().map { outs in
                [out] + outs
            }
        }
    }

    public func manyOrNone<T>(separatedBy separator: Parser<T>) -> Parser<[Output]> {
        return many(separatedBy: separator) | .return([])
    }

    public func ended<T>(by terminator: Parser<T>) -> Parser<Output> {
        return flatMap { res in terminator.map { _ in res } }
    }

    public func followed<T>(by follower: Parser<T>) -> Parser<T> {
        return flatMap { _ in follower }
    }

    public func skipped() -> Parser<()> {
        return map { _ in () }
    }

    public func optional() -> Parser<Output?> {
        return map{$0} | .return(nil)
    }
    
    public static func ~~><B>(_ lhs: Parser<Output>, _ rhs: Parser<B>) -> Parser<B> {
        return lhs.followed(by: rhs)
    }

    public static func <~~<B>(_ lhs: Parser<Output>, _ rhs: Parser<B>) -> Parser<Output> {
        return lhs.ended(by: rhs)
    }

    public static func <*><B>(_ lhs: Parser<(Output) -> B>, _ rhs: Parser<Output>) -> Parser<B> {
        return rhs.apply(lhs)
    }

}

public extension Parser where Output : Associative {

    public func maybeEmpty() -> Parser<Output> {
        return self | .return(Output.identity)
    }

    public func concatenatingResult(with next: Parser<Output>) -> Parser<Output> {
        return flatMap { out1 in
            next.map { out2 in
                out1 + out2
            }
        }
    }

    @inline(__always)
    public func manyConcatenated() -> Parser<Output> {
        return many().concatenated()
    }

    @inline(__always)
    public func manyConcatenatedOrNone() -> Parser<Output> {
        return manyOrNone().concatenated()
    }

    @inline(__always)
    public static func +(lhs: Parser<Output>,
                         rhs: Parser<Output>) -> Parser<Output> {
        return lhs.concatenatingResult(with: rhs)
    }

    @inline(__always)
    public static postfix func +(parser: Parser<Output>) -> Parser<Output> {
        return parser.manyConcatenated()
    }

    @inline(__always)
    public static postfix func *(parser: Parser<Output>) -> Parser<Output> {
        return parser.manyConcatenatedOrNone()
    }

}

public extension Parser where Output : Sequence, Output.Iterator.Element : Associative {

    public func concatenated() -> Parser<Output.Iterator.Element> {
        return map { $0.reduced() }
    }

}

