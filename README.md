# Parsey
Swift Parser Combinator Framework

In addition to simple combinators, **Parsey** supports source location/range tracking, 
backtracking prevention, and custom error messages.

![Parsey Playground](https://pbs.twimg.com/media/CrVaoBeVYAAWWoj.jpg:large)

## Features

- Combinator interface
    - `|`, `~~`, `~~>`, `<~~`, `^^` combinator operators

- Lexer primitives: 
    - `Lexer.whitespace`, `Lexer.signedInteger`, ...

- Regex-like combinators:
    - Postfix `.+` for `.many()`.
        - Example: `let arrayLiteral = "[" ~~> expression.+ <~~ "]"`
    - Postfix `.*` for `.manyOrNone()`.
        - Example: `let classDef = (attribute | method).*`
    - Postfix `.?` for `.optional()`.
        - Example: `let declaration = "let" ~~> id ~~ (":" ~~> type).? ~~ ("=" ~~> expression)`
    - Postfix `+` for `.manyConcatenated()`.
        - Example: `let skippedSpaces = (Lexer.space | Lexer.tab)+`
    - Infix `+` for `.concatenatingResult(with:)`. 
        - Example: `let type = Lexer.upperLetter + Lexer.letter*`
    - `Lexer.regex(_:)` for directly applying regular expressions.
        - Example: `let id = Lexer.regex("[a-zA-Z][a-zA-Z0-9]*")`

- Backtracking prevention 
    - `.!` postfix operator or `.nonbacktracking()`

- Parser tagging for error messages
    - `<!--` operator or `.tagged(_:)`

- Rich error messages with source location
    - For example:
    ```
    Parse failure at 2:4 ----
    (+ %% 1 -20) 2 3)
       ^~~~~~~~~~~~~~
    Expecting an expression, but found "%"
    ```

- Source range tracking
    - `^^^` operator or `.mapParse(_:)`
    - For example, S-expression `\n(+ \n\n(+ +1 -20) 2 3)` gets parsed to
      the following range-tracked AST:
    ```
    Expr:(2:1..<4:16):[
        ID:(2:2..<2:3):+,
        Expr:(4:1..<4:11):[
            ID:(4:2..<4:3):+,
            Int:(4:4..<4:6):1,
            Int:(4:7..<4:10):-20],
        Int:(4:12..<4:13):2,
        Int:(4:14..<4:15):3]
    ```

## Requirements

- Swift 3

- Any operating system

## Package

To use it in your Swift project, add the following dependency to your 
Swift package description file.

```swift
    .Package(url: "https://github.com/rxwei/Parsey", majorVersion: 1)
```

## ⚙ Examples

### 0️⃣ An LLVM Compiler Frontend written in Swift using **Parsey**

[The COOL Programming Language](https://github.com/rxwei/COOL)

### 1️⃣ Parse Left-associative Infix Expressions with Operator Precedence

```swift
indirect enum Expression {
    case integer(Int)
    case symbol(String)
    case infix(String, Expression, Expression)
}

enum Grammar {
    static let integer = Lexer.signedInteger
        ^^ {Int($0)!} ^^ Expression.integer

    static let symbol = Lexer.regex("[a-zA-Z][0-9a-zA-Z]*")
        ^^ Expression.symbol

    static let addOp = Lexer.anyCharacter(in: "+-")
        ^^ { op in { Expression.infix(op, $0, $1) } }
    
    static let multOp = Lexer.anyCharacter(in: "*/")
        ^^ { op in { Expression.infix(op, $0, $1) } }

    /// Left-associative multiplication
    static let multiplication = (integer | symbol).infixedLeft(by: multOp)

    /// Left-associative addition
    static let addition = multiplication.infixedLeft(by: addOp)

    static let expression: Parser<Expression> = addition
}

try print(Grammar.expression.parse("2"))
/// Output:
/// Expression.integer(2)

try print(Grammar.expression.parse("2+1+2*a"))
/// Output:
/// Expression.infix("+",
///                  .infix("+", .integer(2), .integer(1)),
///                  .infix("*", .integer(2), .symbol("a")))
```

### 2️⃣ Parse S-Expressions

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
        "(" ~~> (anExp.!).many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")"
        ^^ Expr.sExp
    static let anExp = anInt | anID | aSExp <!-- "an expression"
}

/// Success
try Grammar.anExp.parse("(+ (+ 1 -20) 2 3)")
/// Output: Expr.sExp(...)

/// Failure
try Grammar.anExp.parse("(+ \n(+ %% 1 -20) 2 3)")
/// Output: Parse failure at 2:4 ----
///         (+ %% 1 -20) 2 3)
///            ^~~~~~~~~~~~~~
///         Expecting an expression, but found "%"
```

### 3️⃣ Parse S-Expressions with Source Range Tracking

```swift
indirect enum Expr {
    case sExp([Expr], SourceRange)
    case int(Int, SourceRange)
    case id(String, SourceRange)
}

enum Grammar {
    static let whitespaces = (Lexer.space | Lexer.tab | Lexer.newLine)+

    static let anInt = Lexer.signedInteger 
        ^^^ { Expr.int(Int($0.target)!, $0.range) }

    static let anID = Lexer.regex("[a-zA-Z_+\\-*/][0-9a-zA-Z_+\\-*/]*")
        ^^^ { Expr.id($0.target, $0.range) }

    static let aSExp: Parser<Expr> =
        "(" ~~> (anExp.!).many(separatedBy: whitespaces).amid(whitespaces.?) <~~ ")"
        ^^^ { Expr.sExp($0.target, $0.range) }

    static let anExp = anInt | anID | aSExp <!-- "an expression"
}

/// Success
try Grammar.anExp.parse("(+ (+ 1 -20) 2 3)")
/// Output: Expr.sExp(...)

/// Failure
try Grammar.anExp.parse("(+ \n(+ %% 1 -20) 2 3)")
/// Output: Parse failure at 2:4 ----
///         (+ %% 1 -20) 2 3)
///            ^~~~~~~~~~~~~~
///         Expecting an expression, but found "%"
```

## Dependency

- [Funky - Functional Programming Library](https://github.com/rxwei/Funky)


## License

MIT License
