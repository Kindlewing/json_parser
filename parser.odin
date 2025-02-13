package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"

Value :: union {
	int,
	string,
	f64,
	bool,
	[dynamic]Value,
	map[string]Value,
}

Parser :: struct {
	line:    int, // current line in json
	current: int,
	tokens:  [dynamic]Token,
}

parse :: proc(src: string) -> map[string]Value {
	tokens := tokenize(src)
	p: Parser = {
		line    = 0,
		current = 0,
		tokens  = tokens,
	}
	json := parse_map(&p)
	return json
}

parse_map :: proc(p: ^Parser) -> map[string]Value {
	m: map[string]Value
	if p.current == 0 && peek_t(p).type != .OPEN_CURLY {
		fmt.eprintf("Invalid start of map. Expected {, got %v\n", peek_t(p))
		os.exit(1)
	}
	// Move past {
	advance_t(p)
	for {
		t := peek_t(p)
		#partial switch t.type {
		case .CLOSE_CURLY:
			advance_t(p)
			return m
		case .NEWLINE:
			p.line += 1
			advance_t(p)
			continue
		case .COMMA:
			advance_t(p)
			continue
		case .STRING:
			key := t.value
			advance_t(p)

			next_token := peek_t(p)
			if next_token.type != .COLON {
				fmt.eprintf(
					"[error: %d] Expected ':', got %v\n",
					p.line,
					next_token,
				)
				os.exit(1)
			}
			// Move past colon
			advance_t(p)

			tok := peek_t(p)
			value := parse_value(p, tok)
			m[key] = value
		case:
			fmt.eprintf("[error: %d] Unexpected token: %v\n", p.line, t)
			os.exit(1)
		}
	}

	return m
}

parse_array :: proc(p: ^Parser) -> [dynamic]Value {
	ret: [dynamic]Value
	for peek_t(p).type != .CLOSE_BRACKET {
		t := peek_t(p)
		#partial switch t.type {
		case .INTEGER, .FLOAT, .BOOLEAN, .STRING:
			val := parse_value(p, t)
			append(&ret, val)
		case:
			advance_t(p)
		}
	}
	// advance past ]
	advance_t(p)
	return ret
}

parse_value :: proc(p: ^Parser, t: Token) -> Value {
	value: Value
	fmt.printf("Parsing token: %v\n", t)

	#partial switch t.type {
	case .OPEN_CURLY:
		value = parse_map(p)
	case .OPEN_BRACKET:
		value = parse_array(p)
	case .BOOLEAN:
		b, ok := strconv.parse_bool(t.value)
		if !ok {
			fmt.eprintf("Invalid bool")
			os.exit(1)
		}
		value = b
		advance_t(p)
	case .STRING:
		value = t.value
		advance_t(p)
	case .FLOAT:
		value = strconv.atof(t.value)
		advance_t(p)
	case .INTEGER:
		i := strconv.atoi(t.value)
		value = i
		advance_t(p)
	}
	return value
}

parse_num :: proc(val: string, current: ^int) -> f64 {
	res: f64
	i := current

	for i^ <= len(val) - 1 {
		n: u8 = val[i^] - cast(u8)'0'
		if n < 10 {
			res = 10.0 * res + cast(f64)n
			i^ += 1
		} else {
			break
		}
	}
	current^ = i^
	return res
}

advance_t :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.current]
	p.current += 1
	return t
}

peek_t :: proc(p: ^Parser) -> Token {
	return p.tokens[p.current]
}

peek_next_t :: proc(p: ^Parser) -> Token {
	return p.tokens[p.current + 1]
}
