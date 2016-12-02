#!/bin/bash

main() {
	local file
	local dir
	local rc
	dir="$DATADIR/$2"
	file="$(mktemp $TMPDIR/XXXXXX)"
	for METHOD in "$CURL" "$WGET"; do
		$METHOD "$1" > $file 2>/dev/null
		rc=$?                   # wget return 8 on 404
		# shellcheck disable=SC2166
		if [ "$rc" -gt 0 ] && ! [ "$rc" = "8" -a "$METHOD" = "$WGET" ]; then
			echo "$1" >> $dir/2
			rm -f $file
			return
		fi
		head -c $FIRST_BYTES_FOR_CHECK "$file" | grep -q "$MARKER"
		echo "$1" >> $dir/$?
		rm -f $file
	done
}

main "$@"
