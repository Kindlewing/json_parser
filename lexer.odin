package main
import "core:fmt"
import "core:log"
import "core:os"


Lexer :: struct {
	src:     string,
	start:   int, // start of current token
	current: int, // current position in src
	line:    int, // current line in json
	tokens:  [dynamic]Token,
}

tokenize :: proc(src: string) -> [dynamic]Token {
	lexer: Lexer = {
		src    = src,
		line   = 1,
		tokens = make([dynamic]Token),
	}

	for !is_at_end(&lexer) {
		c: u8 = advance(&lexer)
		switch c {
		case ' ', '\t':
			consume_whitespace(&lexer)
		case '\n', '\r':
			lexer.line += 1
			append(&lexer.tokens, Token{type = .NEWLINE})
			consume_whitespace(&lexer)
		case '{':
			append(&lexer.tokens, Token{type = .OPEN_CURLY})
		case '}':
			append(&lexer.tokens, Token{type = .CLOSE_CURLY})
		case '[':
			append(&lexer.tokens, Token{type = .OPEN_BRACKET})
		case ']':
			append(&lexer.tokens, Token{type = .CLOSE_BRACKET})
		case ',':
			append(&lexer.tokens, Token{type = .COMMA})
		case ':':
			append(&lexer.tokens, Token{type = .COLON})
		case '"':
			token := str(&lexer)
			append(&lexer.tokens, token)
		case 't', 'f':
			token := boolean(&lexer)
			append(&lexer.tokens, token)
		case:
			if is_digit(c) || c == '-' {
				token := number(&lexer)
				append(&lexer.tokens, token)
			}
		}
	}
	append(&lexer.tokens, Token{type = .EOF})
	return lexer.tokens
}

advance :: proc(lexer: ^Lexer) -> u8 {
	if lexer.current >= len(lexer.src) {
		return 0
	}
	c := lexer.src[lexer.current]
	lexer.current += 1
	return c
}

peek :: proc(lexer: ^Lexer) -> u8 {
	if lexer.current >= len(lexer.src) {
		return 0
	}
	return lexer.src[lexer.current]
}

peek_next :: proc(lexer: ^Lexer) -> u8 {
	if lexer.current >= len(lexer.src) {
		return 0
	}
	return lexer.src[lexer.current + 1]
}

consume_whitespace :: proc(lexer: ^Lexer) {
	for peek(lexer) == ' ' ||
	    peek(lexer) == '\n' ||
	    peek(lexer) == '\t' ||
	    peek(lexer) == '\r' {
		advance(lexer)
	}
}

boolean :: proc(lexer: ^Lexer) -> Token {
	lexer.start = lexer.current - 1
	token: Token
	token.type = .BOOLEAN
	first := lexer.src[lexer.start]

	for !is_at_end(lexer) && peek(lexer) != ',' {
		advance(lexer)
	}
	actual_val: string = lexer.src[lexer.start:lexer.current]
	expected_val: string

	if first == 't' {
		expected_val = "true"
	} else if first == 'f' {
		expected_val = "false"
	}

	if actual_val != expected_val {
		fmt.eprintf(
			"[line: %d] Invalid boolean. Got %s, expected %s\n",
			lexer.line,
			actual_val,
			expected_val,
		)
		os.exit(1)
	}
	token.value = actual_val
	return token
}

str :: proc(lexer: ^Lexer) -> Token {
	lexer.start = lexer.current
	for !is_at_end(lexer) && peek(lexer) != '"' {
		advance(lexer)
	}
	// We don't want the closing '"'
	advance(lexer)
	return Token {
		type = .STRING,
		value = lexer.src[lexer.start:lexer.current - 1],
	}
}

number :: proc(lexer: ^Lexer) -> Token {
	token: Token
	token.type = .INTEGER
	lexer.start = lexer.current - 1

	if lexer.src[lexer.start] == '-' && peek(lexer) == '.' {
		fmt.eprintf("[line: %d] Leading '.' is not allowed\n", lexer.line)
		os.exit(1)
	}
	if lexer.src[lexer.start] == '0' && peek(lexer) != '.' {
		fmt.eprintf("[line: %d] Leading 0's are not allowed\n", lexer.line)
		os.exit(1)
	}
	if lexer.src[lexer.start] == '-' &&
	   peek(lexer) == '0' &&
	   peek_next(lexer) != '.' {
		fmt.eprintf("[line: %d] Leading 0's are not allowed\n", lexer.line)
		os.exit(1)
	}

	if lexer.src[lexer.start] == '-' {
		advance(lexer)
	}

	// Before decimal
	for is_digit(peek(lexer)) && !is_at_end(lexer) {
		advance(lexer)
	}

	if peek(lexer) == '.' {
		token.type = .FLOAT
		advance(lexer)
	}

	// After decimal
	for is_digit(peek(lexer)) && !is_at_end(lexer) {
		advance(lexer)
	}
	token.value = lexer.src[lexer.start:lexer.current]
	return token
}

is_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

is_at_end :: proc(lexer: ^Lexer) -> bool {
	return lexer.current >= len(lexer.src)
}
