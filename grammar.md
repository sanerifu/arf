Expression
    : Identifier
    , Integer
    , Number
    , String
    , LeftParenthesis FunctionCall RightParenthesis
    , Expression DotAmpersand
    , Expression DotAsteriks
    ;

FunctionCall
    : Expression +
    ;

Statement
    : FunctionCall Semicolon
    , Identifier Expression Assign Semicolon
    , Expression Identifier Expression Assign Semicolon
    ;


