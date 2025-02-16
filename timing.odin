package main
import "core:fmt"
import "core:time"

time :: proc(src: string, count: int) {
	sum: f64
	for i in 0 ..< count {

		start := time.now()
		parse(src)
		sum += time.duration_milliseconds(time.since(start))
	}
	fmt.printf("Average over %d iterations: %f\n", count, sum / f64(count))
}
