package main

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

GEN :: #config(GEN, false)

generate_input :: proc(f_path: string, count: int, should_rm: bool) {
	if should_rm {
		os.remove(f_path)
	}
	fd, err := os.open(f_path, os.O_CREATE | os.O_RDWR, 0o775)
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
			"{{\"x0\":\"%f\", \"x1\":\"%f\",\"y0\":\"%f\",\"y1\":\"%f\"}}",
			x0,
			x1,
			y0,
			y1,
		)
		os.write_string(fd, str)
		if i < count - 1 {
			os.write_string(fd, ",")
		}
	}
	os.write_string(fd, "]")
	os.write_string(fd, "}")
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			for _, entry in track.allocation_map {
				fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
			}
		}
		if len(track.bad_free_array) > 0 {
			for entry in track.bad_free_array {
				fmt.eprintf(
					"%v bad free at %v\n",
					entry.location,
					entry.memory,
				)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}
	when GEN {
		generate_input("examples/haversine.json", 10_000, true)
		os.exit(1)
	}

	fd, open_err := os.open("examples/haversine.json", os.O_RDONLY)
	if open_err != nil {
		log.fatalf("There was an error opening the file: %v\n", open_err)
		os.exit(1)
	}
	bytes, ok := os.read_entire_file_from_handle(fd)
	if !ok {
		log.fatalf("There was an error reading the file")
		os.exit(1)
	}
	defer delete_slice(bytes)
	defer os.close(fd)

	src := string(bytes)

	start := time.now()
	json := parse(src)
	fmt.printf(
		"Time to parse: %fms\n",
		time.duration_milliseconds(time.since(start)),
	)

	pairs := json["pairs"].([dynamic]Value)

	for i in 0 ..< len(pairs) {
		x0 := pairs[i].(map[string]Value)["x0"]
		x1 := pairs[i].(map[string]Value)["x1"]
		y0 := pairs[i].(map[string]Value)["y0"]
		y1 := pairs[i].(map[string]Value)["y1"]
	}


	log.destroy_console_logger(context.logger)
	for i in 0 ..< len(pairs) {
		delete(pairs[i].(map[string]Value))
	}
	delete_dynamic_array(pairs)
	delete_map(json)
}
