package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:time"

generate_input :: proc(count: int) {

}

main :: proc() {
	context.logger = log.create_console_logger()
	fd, open_err := os.open("examples/01.json", os.O_RDONLY)
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

	start := time.now()
	json := parse(src)
	fmt.printf(
		"Time to parse: %fms\n",
		time.duration_milliseconds(time.since(start)),
	)


	log.destroy_console_logger(context.logger)
}
