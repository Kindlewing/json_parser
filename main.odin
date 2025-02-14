package main

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:os"
import "core:strings"
import "core:time"

generate_input :: proc(f_path: string, count: int) {
	fd, err := os.open(f_path, os.O_CREATE | os.O_RDWR)
	if err != nil {
		fmt.eprintf("Could not open file: %s\n", err)
		os.exit(-1)
	}
	defer os.close(fd)

	os.write_string(fd, "{\"pairs\": [")
	for i in 0 ..< count {
		x0: f64 = rand.float64_range(-180, 180)
		x1: f64 = rand.float64_range(-180, 180)
		y0: f64 = rand.float64_range(-90, 90)
		y1: f64 = rand.float64_range(-90, 90)
		str: string
		str = fmt.tprintf(
			"{{\"x1\":\"%f\", \"x1\":\"%f\",\"y0\":\"%f\",\"y1\":\"%f\"}},",
			x0,
			x1,
			y0,
			y1,
		)
		os.write_string(fd, str)
	}
	os.write_string(fd, "]")
	os.write_string(fd, "}")
}

main :: proc() {
	context.logger = log.create_console_logger()
	when ODIN_DEBUG {
		generate_input("examples/haversine.json", 10)
		os.exit(1)
	}
	fd, open_err := os.open("examples/haversine.json", os.O_RDONLY)
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
