#!/bin/sh
set -eu

# shellcheck disable=SC2154
info() { lf -remote "send $id echo $*"; }

clear_preview() {
	row_index="$((cursor_y + 2))"
	while [ "${row_index}" -lt "${view_y}" ]; do
		printf "\033[%d;%dH\033[K" "${row_index}" "$((cursor_x + 1))"
		row_index=$((row_index + 1))
	done
	printf "\033[%d;%dH" "$((cursor_y))" "$((cursor_x))"
}

preview_img() {
	if command -v imgcat >/dev/null; then
		## Print a 1x1 black bmp image and clear preview to supprot iterm2 protocol
		# shellcheck disable=SC1003
		printf '\033Pq"1;1;1;1#0;2;0;0;0-#0@\033\'
		clear_preview
		## Adjust cursor position
		printf "\033[%d;%dH" "$((cursor_y + 1))" "$((cursor_x + 1))"

		img_w=1
		img_h=1
		if command -v file >/dev/null; then
			pattern="$(file "${file}" | grep -E -o ', [0-9]+ ?x ?[0-9]+' | grep -E -o '[0-9]+ ?x ?[0-9]+' | sed 's/ //g' || true)"
			if [ -n "${pattern}" ]; then
				img_w=$(echo "${pattern}" | cut -dx -f1)
				img_h=$(echo "${pattern}" | cut -dx -f2)
			fi
		fi

		if [ $((view_x * 50 / view_y)) -gt $((img_w * 100 / img_h)) ]; then
			imgcat "${file}" --height "${view_y}"
		else
			imgcat "${file}" --width "${view_x}"
		fi
	else
		preview_binary
	fi
}

preview_pdf() {
	if command -v pdftotext >/dev/null; then
		pdftotext "${file}" -
	else
		preview_binary
	fi
}

preview_binary() {
	echo "File: $(stat -c%n "${file}")"
	echo "Realpath: $(realpath "${file}")"
	if command -v file >/dev/null; then
		echo Type: "$(file "${file}" | cut -d' ' -f2-)"
		echo "Md5sum: $(md5sum "${file}" | awk '{print $1}' &)"
		echo "Sha256sum: $(sha256sum "${file}" | awk '{print $1}' &)"
		echo "Size: $(du -ahd0 "${file}" | awk '{print $1}') / $(stat -c%s "${file}")"
	fi

	echo "Access: $(stat -c%a "${file}")"
	if test -h "${file}"; then
		echo "Readlink: $(readlink "${file}")"
	else
		if command -v xxd >/dev/null; then
			xxd "${file}" | head -n "${view_y}"
		elif command -v hexdump >/dev/null; then
			hexdump "${file}" | head -n "${view_y}"
		fi
	fi
}

preivew_any() {
	if base64 "${file}" | grep -q "AA"; then
		preview_binary
	else
		head -n "${view_y}" "${file}"
	fi
}

main() {
	file="$1"
	view_x="${2-$(ttysize | awk '{print $1}')}"
	view_y="${3-$(ttysize | awk '{print $2}')}"
	cursor_x="${4-0}"
	cursor_y="${5-0}"
	# shellcheck disable=SC2034
	next_file="${6-}"

	case "${file}" in
	*.tar*) tar tf "${file}" ;;
	*.zip) unzip -l "${file}" ;;
	*.rar) unrar l "${file}" ;;
	*.7z) 7z l "${file}" ;;
	*.pdf) preview_pdf ;;
	*.png | *.jpg | *.tiff | *.gif) preview_img ;;
	*.md) glow --style auto "${file}" ;;
	*) preivew_any ;;
	esac
}

main "$@"
