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
        ]
    }
}
