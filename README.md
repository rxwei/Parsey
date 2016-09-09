# Parsey
The Swiftiest Swift Parser Combinators

In addition to simple combinators, **Parsey** supports

- [x] Backtracking prevention (`.!` postfix operator or `.nonbacktracking()`)
- [x] Parser tagging for error message (`<!--` operator or `.tagged(_:)`)
- [x] Rich error messages with source location
- [x] Source range tracking (`^^^` operator or `.mapParse(_:)`)

## Examples

### A Compiler Frontend written in Swift using **Parsey**

[The COOL Programming Language](https://github.com/rxwei/COOL)

### Parse simple S-Expressions

```swift
indirect enum Expr {
  case sExp([Expr])
  case int(Int)
  case id(String)
}

enum Grammar {
  static let whitespaces = (Lexer.space | Lexer.tab | Lexer.newLine)+
  static let anInt = Lexer.signedInteger ^^ { Int($0)! } ^^ Expr.int
  static let anID = Lexer.regex("[a-zA-Z_+\\-*/][0-9a-zA-Z_+\\-*/]*") ^^ Expr.id
  static let aSExp: Parser<Expr> =
    "(" ~~> (anExp.!).many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")" ^^ Expr.sExp
  static let anExp = anInt | anID | aSExp <!-- "an expression"
}

/// Success
try Grammar.anExp.parse("(+ (+ 1 -20) 2 3)")
/// Output: Expr.sExp(...)

/// Failure
try Grammar.anExp.parse("(+ (+ 龘 1 -20) 2 3)")
/// Output: Parse failure at 1:7 ----
///           龘 1 -20) 2 3)
///         Expecting an expression, but found "龘"
```

### Parse S-Expressions with Source Range Tracking

```swift
indirect enum Expr {
  case sExp([Expr], SourceRange)
  case int(Int, SourceRange)
  case id(String, SourceRange)
}

enum Grammar {
  static let whitespaces = (Lexer.space | Lexer.tab | Lexer.newLine)+
  static let anInt = Lexer.signedInteger ^^^ { Expr.int(Int($0.target)!, $0.range) }
  static let anID = Lexer.regex("[a-zA-Z_+\\-*/][0-9a-zA-Z_+\\-*/]*").mapParse { parse in
    Expr.id(parse.target, parse.range)
  }
  static let aSExp: Parser<Expr> =
    "(" ~~> (anExp.!).many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")"
    ^^^ { Expr.sExp($0.target, $0.range) }
  static let anExp = anInt | anID | aSExp <!-- "an expression"
}

/// Success
try Grammar.anExp.parse("(+ (+ 1 -20) 2 3)")
/// Output: Expr.sExp(...)

/// Failure
try Grammar.anExp.parse("(+ (+ 龘 1 -20) 2 3)")
/// Output: Parse failure at 1:7 ----
///           龘 1 -20) 2 3)
///         Expecting an expression, but found "龘"
```

## License

MIT License
