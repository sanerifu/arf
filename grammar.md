ExpressionSuffix
    : Addressof
    , Dereference
    , Dot Identifier
    , Dot LeftParenthesis Expression+ RightParenthesis
    , LeftBracket Expression RightBracket
    , Ampersand
    ;

ExpressionBase
    : Identifier
    , Integer
    , Number
    , String
    , LeftParenthesis Expression+ RightParenthesis
    , LeftBracket Expression* RightBracket
    , LeftBrace (Identifier Expression)* RightBrace
    ;

Expression
    : ExpressionBase ExpressionSuffix*
    ;

 Statement
    : Expression+ Semicolon
    , Expression Expression Assign Semicolon
    , Expression Expression Expression Assign Semicolon
    ;

