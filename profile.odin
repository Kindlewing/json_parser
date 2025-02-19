package main

import "core:fmt"
import "core:os"
import str "core:strings"
import "core:sys/posix"
import "core:time"

COUNTER: u64 = 0

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
	anchor_idx: u64,
}

global_prof: profiler

read_os_timer :: proc() -> u64 {
	t: posix.timeval
	tzp: uintptr = 0
	posix.gettimeofday(&t, cast(rawptr)tzp)
	freq, _ := time.tsc_frequency()
	res: u64 = freq * cast(u64)t.tv_sec + cast(u64)t.tv_usec
	return res
}

estimate_cpu_freq :: proc() -> u64 {
	os_freq, _ := time.tsc_frequency()
	ms_to_wait: u64 = 100
	cpu_start: u64 = time.read_cycle_counter()
	os_start: u64 = read_os_timer()
	os_end: u64 = 0
	os_elapsed: u64 = 0
	os_wait_time: u64 = os_freq * ms_to_wait / 1000
	for os_elapsed < os_wait_time {
		os_end = read_os_timer()
		os_elapsed = os_end - os_start
	}
	cpu_end: u64 = time.read_cycle_counter()
	cpu_elapsed: u64 = cpu_end - cpu_start
	cpu_freq: u64 = 0
	if os_elapsed != 0 {
		cpu_freq = os_freq * cpu_elapsed / os_elapsed
	}
	fmt.printf("CPU freq: %d\n", cpu_freq)
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

create_profile_block :: proc(label: string, anchor_idx: u64) -> profile_block {
	prof: profile_block = {
		anchor_idx = anchor_idx,
		label      = label,
		start_tsc  = time.read_cycle_counter(),
	}
	return prof
}

destroy_profile_block :: proc(prof: ^profile_block) {
	elapsed: u64 = time.read_cycle_counter() - prof.start_tsc
	anchor: profile_anchor = global_prof.anchors[0 + prof.anchor_idx]
	anchor.tsce_elapsed += elapsed
	anchor.hit_count += 1
	anchor.label = prof.label
}

time_block :: proc(name: string, loc := #caller_location) {
	fmt.printf("Timing %s\n", loc.procedure)
	COUNTER += 1
	prof := create_profile_block(name, COUNTER)
	defer destroy_profile_block(&prof)
}

time_function :: proc(loc := #caller_location) {
	fmt.printf("Timing %s\n", loc.procedure)
	time_block(loc.procedure)
}

start_profile :: proc() {
	fmt.printf("BEGIN PROFILE\n")
	global_prof.start_tsc = time.read_cycle_counter()
	fmt.printf("READ CYCLE COUNTER\n")
}

end_and_print_profile :: proc() {
	global_prof.end_tsc = time.read_cycle_counter()
	cpu_freq: u64 = estimate_cpu_freq()
	total_cpu_elapsed: u64 = global_prof.end_tsc - global_prof.start_tsc
	fmt.printf("CPU freq: %d\n", cpu_freq)
	if cpu_freq != 0 {
		fmt.printf(
			"\nTotal time: %0.4fms (CPU freq %llu)\n",
			1000.0 * cast(f64)total_cpu_elapsed / cast(f64)cpu_freq,
			cpu_freq,
		)
	}
	for anchor_idx in 0 ..< len(global_prof.anchors) {
		anchor: profile_anchor = global_prof.anchors[0 + anchor_idx]
		if anchor.tsce_elapsed != 0 {
			print_time_elapsed(total_cpu_elapsed, &anchor)
		}

	}
}
