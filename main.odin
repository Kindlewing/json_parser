package main

import "core:log"
import "core:os"
import "lexer"

main :: proc() {
	fd, open_err := os.open("examples/00.json", os.O_RDONLY)
	if open_err != nil {
		log.fatalf("There was an error opening the file: %v\n", open_err)
		os.exit(1)
	}
	defer os.close(fd)
	bytes, ok := os.read_entire_file_from_handle(fd)
	if !ok {
		log.fatalf("There was an error reading the file")
		os.exit(1)
	}

	src := string(bytes)
	lexer.tokenize(src)

	log.debugf("Json: %s\n", src)
}
