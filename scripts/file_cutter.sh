#!/usr/bin/env bash

read_lines() {
	local file="$1"
	local from_line="$2"
	local lines_count="$3"
	tail -n +$from_line $file | head -$lines_count
}

main() {
	local file="$1"
	local parts="$2"
	local lines lines_per_part
    lines="$(wc -l < $file)"
    lines_per_part=$((lines/parts))
    rm -rf $file.parts/
	mkdir -p $file.parts/
	for part in $(seq 0 $((parts-1))); do
		read_lines $file $((part * lines_per_part + 1)) $lines_per_part > $file.parts/$part
	done
    tail -n $((lines- lines_per_part * parts)) $file > $file.parts/$parts
}

main "$@"
