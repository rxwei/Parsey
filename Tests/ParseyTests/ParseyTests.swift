import XCTest
@testable import Parsey

class ParseyTests: XCTestCase {

    func testIntegers() throws {
        try XCTAssertEqual(Lexer.unsignedInteger.flatMap{Int($0)}.parse("12345"), 12345)
        try XCTAssertEqual(Lexer.signedInteger.flatMap{Int($0)}.parse("12345"), 12345)
        try XCTAssertEqual(Lexer.signedInteger.flatMap{Int($0)}.parse("-12345"), -12345)
        try XCTAssertEqual(Lexer.signedInteger.flatMap{Int($0)}.parse("+12345"), 12345)
    }

    func testSourceRange() throws {
        indirect enum Expr : CustomStringConvertible {
            case sExp([Expr], SourceRange)
            case int(Int, SourceRange)
            case id(String, SourceRange)

            var description: String {
                switch self {
                    case let .sExp(exps, range): return "Expr:(\(range)):\(exps)"
                    case let .int(i, range): return "Int:(\(range)):\(i)"
                    case let .id(id, range): return "ID:(\(range)):\(id)"
                }
            }
        }

        enum Grammar {
            static let whitespaces = Lexer.regex("[ \n\r]+")
            static let anInt = Lexer.signedInteger ^^& { Expr.int(Int($0.target)!, $0.range) }
            static let anID = Lexer.regex("[a-zA-Z_+\\-*/][0-9a-zA-Z_+\\-*/]*").mapParse { parse in
                Expr.id(parse.target, parse.range)
            }

            static let aSExp: Parser<Expr> =
                "(" ~~> anExp.nonbacktracking().many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")"
                    ^^& { Expr.sExp($0.target, $0.range) }

            static let anExp = anInt | anID | aSExp <!-- "an expression"
        }

        do {
            let ast = try Grammar.anExp.amid(Grammar.whitespaces.?).parse("\n(+\n\n \n(+ +1 -1)\n 2 3)")
            print("Checking source ranges:\n\(ast)")
        }
        catch let error as ParseFailure {
            print(error.description)
        }
    }

    func testLeftAssociativeOperator() throws {
        indirect enum Expression : CustomStringConvertible {
            case integer(Int, SourceRange)
            case symbol(String, SourceRange)
            case infix(String, Expression, Expression, SourceRange)

            var description: String {
                switch self {
                case let .integer(i, sr): return "\(i):\(sr)"
                case let .symbol(s, sr): return "\(s):\(sr)"
                case let .infix(o, l, r, sr): return "(\(o) \(l) \(r)):\(sr)"
                }
            }
        }

        enum Grammar {
            static let integer = Lexer.signedInteger
                ^^ {Int($0)!} ^^^ Expression.integer

            static let symbol = Lexer.regex("[a-zA-Z][0-9a-zA-Z]*")
                ^^^ Expression.symbol

            static let addOp = Lexer.anyCharacter(in: "+-")
                ^^ { op in { lhs, rhs, sr in Expression.infix(op, lhs, rhs, sr) } }
            
            static let multOp = Lexer.anyCharacter(in: "*/")
                ^^ { op in { lhs, rhs, sr in Expression.infix(op, lhs, rhs, sr) } }

            /// Left-associative multiplication
            static let multiplication = (integer | symbol).infixedLeft(by: multOp)
            /// Left-associative addition
            static let addition = multiplication.infixedLeft(by: addOp)

            static let expression: Parser<Expression> = addition
        }

        do {
            try print(Grammar.expression.parse("2"))
            /// Result: 2
            try print(Grammar.expression.parse("2+1+2*a+4*5+6"))
            /// Result: (+ (+ (+ (+ 2 1) (* 2 a)) (* 4 5)) 6)
        }
        catch let error as ParseFailure {
            XCTFail(error.description)
        }
    }

    func testStrings() throws {
        try XCTAssertEqual(Lexer.token("Hello").parse("Hello"), "Hello")
        try XCTAssertEqual(Lexer.regex("(Hello)*").parse("HelloHelloHello"), "HelloHelloHello")
        try XCTAssertEqual((Lexer.whitespaces ~~> Lexer.regex("(Hello)*")).parse(" HelloHelloHello"), "HelloHelloHello")
    }

    func testNonAsciiCharacters() throws {
        try XCTAssertEqual(Lexer.token("あ").parse("あ"), "あ")
        try XCTAssertEqual(Lexer.token("שלום").parse("שלום"), "שלום")
        try XCTAssertEqual(Lexer.token("مرحبا").parse("مرحبا"), "مرحبا")
        try XCTAssertEqual(Lexer.token("🐶").parse("🐶"), "🐶")
        try XCTAssertEqual(Lexer.regex("(あ)*").parse("あああ"), "あああ")
        try XCTAssertEqual((Lexer.whitespaces ~~> Lexer.regex("(あ)*")).parse(" あああ"), "あああ")
    }

    static var allTests = [
        ("testIntegers", testIntegers),
        ("testSourceRange", testSourceRange),
        ("testLeftAssociativeOperator", testLeftAssociativeOperator),
        ("testStrings", testStrings),
        ("testNonAsciiCharacters", testNonAsciiCharacters),
    ]
}
