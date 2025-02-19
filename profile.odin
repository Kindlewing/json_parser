package main

import "core:fmt"
import "core:time"

profile_anchor :: struct {
	tsce_elapsed: u64,
	hit_count:    u64,
	label:        string,
}

profiler :: struct {
	anchors:   [4096]profile_anchor,
	start_tsc: u64,
	end_tsc:   u64,
}

profile_block :: struct {
	label:      string,
	start_tsc:  u64,
	anchor_idx: u32,
}

estimate_cpu_freq :: proc() -> u64 {
	freq, _ := time.tsc_frequency()
	ms_to_wait: u64 = 100
	cpu_start: u64 = time.read_cycle_counter()
	cpu_freq: u64

	return cpu_freq
}

print_time_elapsed :: proc(
	total_tsce_time_elapsed: u64,
	anchor: ^profile_anchor,
) {
	elapsed: u64 = anchor.tsce_elapsed
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
	prof.start_tsc = time.read_cycle_counter()
}

end_and_print_profile :: proc(prof: ^profiler) {
	prof.end_tsc = time.read_cycle_counter()
	cpu_freq: i64 = estimate_cpu_freq()
}
