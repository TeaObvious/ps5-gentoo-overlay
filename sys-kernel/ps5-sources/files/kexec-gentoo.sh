#!/bin/sh
# Switch to Gentoo Linux via kexec
set -e

BOOT=/boot/efi

kexec -l "$BOOT/bzImage-gentoo" \
	--initrd="$BOOT/initrd-gentoo.img" \
	--command-line="$(cat "$BOOT/cmdline-gentoo.txt")"

kexec -e
