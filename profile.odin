package main

import "core:fmt"
import "core:os"
import str "core:strings"
import "core:sys/posix"
import "core:time"

COUNTER: u64 = 1
profile_indices: map[string]u64 = make_map_cap(map[string]u64, 4096)


global_prof: profiler
global_anchors: [4096]profile_anchor
global_prof_parent: u64 = 0


profile_anchor :: struct {
	tsc_elapsed_exclusive: u64, // without children
	tsc_elapsed_inclusive: u64, // with children
	bytes_processed:       u64,
	hit_count:             u64,
	label:                 string,
}

profiler :: struct {
	start_tsc: u64,
	end_tsc:   u64,
}

profile_block :: struct {
	label:                     string,
	start_tsc:                 u64,
	old_tsc_elapsed_inclusive: u64,
	anchor_idx:                u64,
	parent_idx:                u64,
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

estimate_block_timer_freq :: proc() -> u64 {
	ms_to_wait: u64 = 100
	os_freq, _ := time.tsc_frequency()
	block_start: u64 = time.read_cycle_counter()
	os_start: u64 = read_os_timer()
	os_end: u64 = 0
	os_elapsed: u64 = 0
	os_wait_time: u64 = os_freq * ms_to_wait / 1000

	for os_elapsed < os_wait_time {
		os_end = read_os_timer()
		os_elapsed = os_end - os_start
	}
	block_end: u64 = time.read_cycle_counter()
	block_elapsed: u64 = block_end - block_start
	block_freq: u64 = 0

	if os_elapsed != 0 {
		block_freq = os_freq * block_elapsed / os_elapsed
	}
	return block_freq

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


create_profile_block :: proc(
	label: string,
	anchor_idx: u64,
	byte_count: u64,
) -> profile_block {
	prof: profile_block = {
		parent_idx                = global_prof_parent,
		anchor_idx                = anchor_idx,
		label                     = label,
		old_tsc_elapsed_inclusive = global_anchors[anchor_idx].tsc_elapsed_inclusive,
	}
	global_prof_parent = prof.anchor_idx
	global_anchors[anchor_idx].bytes_processed += byte_count
	prof.start_tsc = time.read_cycle_counter()
	return prof
}

destroy_profile_block :: proc(prof: ^profile_block) {
	elapsed: u64 = time.read_cycle_counter() - prof.start_tsc
	global_prof_parent = prof.parent_idx

	parent: ^profile_anchor = &global_anchors[prof.parent_idx]
	anchor: ^profile_anchor = &global_anchors[prof.anchor_idx]

	parent.tsc_elapsed_exclusive -= elapsed
	anchor.tsc_elapsed_exclusive += elapsed
	anchor.tsc_elapsed_inclusive = prof.old_tsc_elapsed_inclusive + elapsed
	anchor.hit_count += 1
	anchor.label = prof.label


}

time_block :: proc(name: string, loc := #caller_location) -> profile_block {
	return time_bandwidth(name, 0)
}

time_bandwidth :: proc(name: string, byte_count: u64) -> profile_block {
	idx: u64
	if idx_ptr := profile_indices[name]; idx_ptr != 0 {
		idx = idx_ptr
	} else {
		COUNTER += 1
		assert(COUNTER < len(global_anchors))
		idx = COUNTER
		profile_indices[name] = idx
	}
	return create_profile_block(name, idx, byte_count)
}

time_function :: proc(loc := #caller_location) -> profile_block {
	return time_block(loc.procedure)
}

start_profile :: proc() {
	global_prof.start_tsc = time.read_cycle_counter()
}

print_anchor_data :: proc(elapsed: u64, cpu_freq: u64) {
	for idx in 0 ..< len(global_anchors) {
		anchor: profile_anchor = global_anchors[idx]
		if anchor.tsc_elapsed_inclusive != 0 {
			print_time_elapsed(elapsed, cpu_freq, &anchor)
		}
	}
}

print_time_elapsed :: proc(
	total_tsc_time_elapsed: u64,
	timer_freq: u64,
	anchor: ^profile_anchor,
) {
	percent: f64 =
		100.0 *
		(cast(f64)anchor.tsc_elapsed_exclusive /
				cast(f64)total_tsc_time_elapsed)
	fmt.printf(
		"  %s[%d]: %d (%.2f%%",
		anchor.label,
		anchor.hit_count,
		anchor.tsc_elapsed_exclusive,
		percent,
	)
	if anchor.tsc_elapsed_inclusive != anchor.tsc_elapsed_exclusive {
		percent_with_children: f64 =
			100.0 *
			(cast(f64)anchor.tsc_elapsed_inclusive /
					cast(f64)total_tsc_time_elapsed)
		fmt.printf(", %.2f%% w/children", percent_with_children)
	}
	fmt.printf(")")

	if anchor.bytes_processed != 0 {
		megabyte: f64 = 1024.0 * 1024.0
		gigabyte: f64 = megabyte * 1024.0
		seconds: f64 =
			cast(f64)anchor.tsc_elapsed_inclusive / cast(f64)timer_freq
		bytes_per_sec: f64 = cast(f64)anchor.bytes_processed / seconds
		megabytes: f64 = cast(f64)anchor.bytes_processed / cast(f64)megabyte
		gigabytes_per_sec: f64 = bytes_per_sec / gigabyte
		fmt.printf("  %.3fmb at %.2fgb/s", megabytes, gigabytes_per_sec)
	}
	fmt.printf("\n")
}

end_and_print_profile :: proc() {
	global_prof.end_tsc = time.read_cycle_counter()
	block_freq: u64 = estimate_block_timer_freq()
	total_cpu_elapsed: u64 = global_prof.end_tsc - global_prof.start_tsc
	if block_freq != 0 {
		fmt.printf(
			"\nTotal time: %0.4fms (Timer freq %d)\n",
			1000.0 * cast(f64)total_cpu_elapsed / cast(f64)block_freq,
			block_freq,
		)
	}
	print_anchor_data(total_cpu_elapsed, block_freq)
}
