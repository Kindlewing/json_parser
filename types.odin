package main

TokenType :: enum int {
	OPEN_BRACKET,
	CLOSE_BRACKET,
	OPEN_CURLY,
	CLOSE_CURLY,
	COLON,
	COMMA,
	STRING,
	INTEGER,
	FLOAT,
	BOOLEAN,
	NEWLINE,
	EOF,
}

Token :: struct {
	type:  TokenType,
	value: string,
}
