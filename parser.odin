package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"

Value :: union {
	int,
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
	if peek_t(p).type != .OPEN_CURLY {
		fmt.eprintf(
			"Invalid start of map: expected {, got %v\n",
			peek_t(p).type,
		)
		os.exit(1)
	}

	for peek_t(p).type != .CLOSE_CURLY {
		// expecting value here
		t := advance_t(p)
		key: string
		value: Value

		#partial switch t.type {
		case .NEWLINE:
			p.line += 1
			continue
		case .STRING:
			key = t.value
			next_token := advance_t(p)
			if next_token.type != .COLON {
				fmt.eprintf("[error: %d] Expected  ':'\n", p.line)
				os.exit(1)
			}
			value = parse_value(p)
		case:
			continue
		}

		if value != nil {
			m[key] = value
		}
	}
	return m
}

parse_array :: proc(p: ^Parser) -> [dynamic]Value {
	ret: [dynamic]Value
	for {
		t := advance_t(p)
		if t.type == .OPEN_BRACKET {
			continue
		}
		if t.type == .COMMA {
			continue
		}

		if t.type == .CLOSE_BRACKET {
			break
		}
		fmt.printf("About to parse float: %s\n", t.value)
		value := parse_value(p)
		if value != nil {
			append(&ret, value)
		}
	}
	// go past closing ]
	advance_t(p)

	return ret
}

parse_value :: proc(p: ^Parser) -> Value {
	t := peek_t(p)
	value: Value

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
		p.current += 1
	case .FLOAT:
		value = parse_float(p)
	case .INTEGER:
		i := strconv.atoi(t.value)
		value = i
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

parse_float :: proc(p: ^Parser) -> f64 {
	val := p.tokens[p.current].value
	res: f64
	i: int
	sign := 1.0
	if val[0] == '-' {
		sign = -1.0
		i += 1
	}

	n: f64 = parse_num(val, &i)
	if (i <= len(p.tokens)) && val[i] == '.' {
		i += 1
		c: f64 = 1.0 / 10.0
		for i < len(val) {
			char: u8 = val[i] - cast(u8)'0'
			if char < 10 {
				n = n + c * cast(f64)char
				c *= 1.0 / 10.0
				i += 1
			} else {
				break
			}
		}
	}
	res = sign * n
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
