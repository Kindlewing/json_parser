package main

import "core:fmt"
import "core:os"
import str "core:strings"
import "core:sys/posix"
import "core:time"

COUNTER: u64 = 1


global_prof: profiler
global_prof_parent: u64 = 0


profile_anchor :: struct {
	tsc_elapsed:          u64,
	tsc_elapsed_children: u64,
	tsc_elapsed_at_root:  u64,
	hit_count:            u64,
	label:                string,
}

profiler :: struct {
	anchors:   [4096]profile_anchor,
	start_tsc: u64,
	end_tsc:   u64,
}

profile_block :: struct {
	label:                   string,
	start_tsc:               u64,
	old_tsc_elapsed_at_root: u64,
	anchor_idx:              u64,
	parent_idx:              u64,
}

hash_string :: proc(s: string) -> u64 {
	h: u64 = 5381
	for c in s {
		h = ((h << 5) + h) + cast(u64)c // h * 33 + c
	}
	return h
}

read_os_timer :: proc() -> u64 {
	t: posix.timespec
	if posix.clock_gettime(posix.Clock.MONOTONIC, &t) != nil {
		fmt.printf("ERROR: clock_gettime failed\n")
		return 0
	}
	freq, _ := time.tsc_frequency()
	res: u64 = freq * cast(u64)t.tv_sec + cast(u64)(t.tv_nsec / 1000)
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
	return cpu_freq
}

print_time_elapsed :: proc(
	total_tsc_time_elapsed: u64,
	anchor: ^profile_anchor,
) {
	elapsed: u64 = anchor.tsc_elapsed - anchor.tsc_elapsed_children
	percent: f64 = 100.0 * (cast(f64)elapsed / cast(f64)total_tsc_time_elapsed)
	fmt.printf(
		"  %s[%d]: %d (%.2f%%",
		anchor.label,
		anchor.hit_count,
		elapsed,
		percent,
	)
	if anchor.tsc_elapsed_children != 0 {
		percent_with_children: f64 =
			100.0 *
			(cast(f64)anchor.tsc_elapsed_at_root /
					cast(f64)total_tsc_time_elapsed)
		fmt.printf(", %.2f%% w/children", percent_with_children)
	}
	fmt.printf(")\n")
}

create_profile_block :: proc(label: string, anchor_idx: u64) -> profile_block {
	prof: profile_block = {
		parent_idx              = global_prof_parent,
		anchor_idx              = anchor_idx,
		label                   = label,
		old_tsc_elapsed_at_root = global_prof.anchors[anchor_idx].tsc_elapsed_at_root,
	}
	prof.start_tsc = time.read_cycle_counter()
	global_prof_parent = prof.anchor_idx
	return prof
}

destroy_profile_block :: proc(prof: ^profile_block) {
	elapsed: u64 = time.read_cycle_counter() - prof.start_tsc
	global_prof_parent = prof.parent_idx
	global_prof.anchors[prof.anchor_idx].tsc_elapsed += elapsed
	global_prof.anchors[prof.parent_idx].tsc_elapsed_children += elapsed
	global_prof.anchors[prof.anchor_idx].tsc_elapsed_at_root =
		prof.old_tsc_elapsed_at_root + elapsed

	global_prof.anchors[prof.anchor_idx].hit_count += 1
	global_prof.anchors[prof.anchor_idx].label = prof.label
}

time_block :: proc(name: string, loc := #caller_location) -> profile_block {
	h: u64 = hash_string(name) % len(global_prof.anchors)
	assert(h <= len(global_prof.anchors))
	return create_profile_block(name, h)
}

time_function :: proc(loc := #caller_location) -> profile_block {
	return time_block(loc.procedure)
}

start_profile :: proc() {
	global_prof.start_tsc = time.read_cycle_counter()
}

end_and_print_profile :: proc() {
	global_prof.end_tsc = time.read_cycle_counter()
	cpu_freq: u64 = estimate_cpu_freq()
	total_cpu_elapsed: u64 = global_prof.end_tsc - global_prof.start_tsc
	fmt.printf("CPU Freq: %d\n", cpu_freq)
	if cpu_freq != 0 {
		fmt.printf(
			"\nTotal time: %0.4fms (CPU freq %d)\n",
			1000.0 * cast(f64)total_cpu_elapsed / cast(f64)cpu_freq,
			cpu_freq,
		)
	}

	for anchor_idx in 0 ..< len(global_prof.anchors) {
		anchor: profile_anchor = global_prof.anchors[0 + anchor_idx]
		if anchor.tsc_elapsed != 0 {
			print_time_elapsed(total_cpu_elapsed, &anchor)
		}

	}
}
