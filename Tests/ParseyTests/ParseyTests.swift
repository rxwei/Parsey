import XCTest
@testable import Parsey

class ParseyTests: XCTestCase {

    func testIntegers() {
        do {
            try XCTAssertEqual(Lexer.unsignedInteger.map{Int($0)!}.parse("12345"), 12345)
            try XCTAssertEqual(Lexer.signedInteger.map{Int($0)!}.parse("12345"), 12345)
            try XCTAssertEqual(Lexer.signedInteger.map{Int($0)!}.parse("-12345"), -12345)
            try XCTAssertEqual(Lexer.signedInteger.map{Int($0)!}.parse("+12345"), 12345)
        }
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
            static let whitespaces = (Lexer.space | Lexer.tab | Lexer.newLine)+
            static let anInt = Lexer.signedInteger ^^^ { Expr.int(Int($0.target)!, $0.range) }
            static let anID = Lexer.regex("[a-zA-Z_+\\-*/][0-9a-zA-Z_+\\-*/]*").mapParse { parse in
                Expr.id(parse.target, parse.range)
            }

            static let aSExp: Parser<Expr> =
                "(" ~~> anExp.nonbacktracking().many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")" ^^^ { Expr.sExp($0.target, $0.range) }

            static let anExp = anInt | anID | aSExp <!-- "an expression"
        }

        do {
            let ast = try Grammar.anExp.amid(Grammar.whitespaces.?).parse("(+ (+ 发 +1 -20) 2 3)")
            print("Checking source ranges:\n\(ast)")
        }
        catch let error as ParseFailure {
            XCTFail(error.description)
        }
    }

    func testStrings() {
        do {
            try XCTAssertEqual(Lexer.string("Hello").parse("Hello"), "Hello")
            try XCTAssertEqual(Lexer.regex("(Hello)*").parse("HelloHelloHello"), "HelloHelloHello")
            try XCTAssertEqual((Lexer.whitespaces ~~> Lexer.regex("(Hello)*")).parse(" HelloHelloHello"), "HelloHelloHello")
        }
    }

    static var allTests : [(String, (ParseyTests) -> () throws -> Void)] {
        return [
            ("testIntegers", testIntegers),
            ("testSourceRange", testSourceRange),
            ("testStrings", testStrings),
        ]
    }
}
