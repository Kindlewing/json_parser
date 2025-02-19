package main

import "base:intrinsics"
import "core:fmt"
import "core:time"

profile_anchor :: struct {
	tsce_elapsed: i64,
	hit_count:    i64,
	label:        string,
}

profiler :: struct {
	anchors:   [4096]profile_anchor,
	start_tsc: i64,
	end_tsc:   i64,
}

profile_block :: struct {
	label:      string,
	start_tsc:  i64,
	anchor_idx: i32,
}

estimate_cpu_freq :: proc() -> i64 {
	freq, _ := time.tsc_frequency()
	ms_to_wait: i64 = 100

	return 20000000000000
}

print_time_elapsed :: proc(
	total_tsce_time_elapsed: i64,
	anchor: ^profile_anchor,
) {
	elapsed: i64 = anchor.tsce_elapsed
	percent: f64 =
		100.0 * (cast(f64)elapsed / cast(f64)total_tsce_time_elapsed)
	fmt.printf(
		"  %s[%llu]: %llu (%.2f%%)\n",
		anchor.label,
		anchor.hit_count,
		elapsed,
		percent,
	)
}

start_profile :: proc(prof: ^profiler) {
	prof.start_tsc = intrinsics.read_cycle_counter()
}

end_and_print_profile :: proc(prof: ^profiler) {
	prof.end_tsc = intrinsics.read_cycle_counter()
	cpu_freq: i64 = estimate_cpu_freq()
}
