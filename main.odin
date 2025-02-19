package main

import "core:fmt"
import "core:log"
import m "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

GEN :: #config(GEN, false)
N :: #config(N, 1_000)

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
			"{{\"x0\":%f, \"x1\":%f,\"y0\":%f,\"y1\":%f}}",
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

radians_from_deg :: proc(deg: f64) -> f64 {
	return deg * (m.PI / 180)
}

sqr :: proc(n: f64) -> f64 {
	return n * n
}

haversine :: proc(x0, x1, y0, y1: f64, radius: f64) -> f64 {
	lat1 := radians_from_deg(x0)
	lat2 := radians_from_deg(x1)
	lon1 := radians_from_deg(y0)
	lon2 := radians_from_deg(y1)

	d_lat: f64 = radians_from_deg(lat2 - lat1)
	d_lon: f64 = radians_from_deg(lon2 - lon1)

	a: f64 =
		sqr(m.sin(d_lon / 2)) +
		m.cos(lon1) * m.cos(lon2) * (sqr(m.sin(d_lat / 2)))
	c: f64 = 2 * m.asin(m.sqrt(a))
	return radius * c
}
main :: proc() {
	start_profile()
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
		generate_input("examples/haversine.json", N, true)
		os.exit(1)
	}

	fmt.printf("About to read file\n")
	fd, open_err := os.open("example/haversine.json", os.O_RDONLY)
	if open_err != nil {
		log.fatalf("There was an error opening the file: %v\n", open_err)
		os.exit(1)
	}
	bytes, ok := os.read_entire_file_from_handle(fd)
	if !ok {
		log.fatalf("There was an error reading the file")
		os.exit(1)
	}

	defer os.close(fd)
	defer delete_slice(bytes)

	src := string(bytes)
	json := parse(src)

	pairs := json["pairs"].([dynamic]Value)
	result: f64 = 0.0
	count: int


	for i in 0 ..< len(pairs) {
		lat1 := pairs[i].(map[string]Value)["x0"].(f64)
		lat2 := pairs[i].(map[string]Value)["x1"].(f64)
		lon1 := pairs[i].(map[string]Value)["y0"].(f64)
		lon2 := pairs[i].(map[string]Value)["y1"].(f64)
		res := haversine(lat1, lat2, lon1, lon2, 6371.8)
		result += res
		count += 1
	}
	avg: f64 = result / cast(f64)count

	fmt.printf("average haversine: %f\n", avg)

	log.destroy_console_logger(context.logger)
	for i in 0 ..< len(pairs) {
		delete(pairs[i].(map[string]Value))
	}
	delete_dynamic_array(pairs)
	delete_map(json)
}
