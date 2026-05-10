# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="Linux kernel sources patched and configured for PlayStation 5"
HOMEPAGE="https://github.com/ps5-linux/ps5-linux-patches"
LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE=""
PROPERTIES="live"

BDEPEND="
	dev-build/make
	dev-vcs/git
"

RDEPEND="
	sys-kernel/genkernel
	sys-libs/binutils-libs
	dev-libs/elfutils
"

PS5_PATCHES_REPO="https://github.com/ps5-linux/ps5-linux-patches.git"
LINUX_STABLE_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

PS5_PATCHES_DIR="${WORKDIR}/ps5-linux-patches"
LINUX_SRC_DIR="${WORKDIR}/linux"

S="${LINUX_SRC_DIR}"

# Fallback for the current upstream ps5-linux-patches README.
# The ebuild still tries to derive the kernel version from the PS5 .config first.
PS5_FALLBACK_KERNEL_VERSION="7.0.5"

src_unpack() {
	local kernel_version

	einfo "Fetching ps5-linux patches/config"
	EGIT_REPO_URI="${PS5_PATCHES_REPO}"
	EGIT_BRANCH="main"
	unset EGIT_COMMIT
	EGIT_CLONE_TYPE="shallow"
	EGIT_CHECKOUT_DIR="${PS5_PATCHES_DIR}"
	git-r3_src_unpack

	if [[ ! -f "${PS5_PATCHES_DIR}/.config" ]]; then
		die "Missing upstream PS5 kernel config: ${PS5_PATCHES_DIR}/.config"
	fi

	kernel_version="$(
		sed -n -E \
			's/^# Linux\/.* ([0-9]+\.[0-9]+(\.[0-9]+)?) Kernel Configuration$/\1/p' \
			"${PS5_PATCHES_DIR}/.config" | head -n1
	)"

	if [[ -z ${kernel_version} ]]; then
		kernel_version="${PS5_FALLBACK_KERNEL_VERSION}"
		ewarn "Could not derive kernel version from .config; falling back to v${kernel_version}"
	fi

	einfo "Fetching Linux stable kernel v${kernel_version}"
	EGIT_REPO_URI="${LINUX_STABLE_REPO}"
	unset EGIT_BRANCH
	EGIT_COMMIT="v${kernel_version}"
	EGIT_CLONE_TYPE="shallow"
	EGIT_CHECKOUT_DIR="${LINUX_SRC_DIR}"
	git-r3_src_unpack

	echo "${kernel_version}" > "${WORKDIR}/ps5-kernel-version" || die
}

src_prepare() {
	cd "${LINUX_SRC_DIR}" || die

	if [[ -f "${PS5_PATCHES_DIR}/linux.patch" ]]; then
		einfo "Applying PS5 linux.patch"
		git apply --exclude=Makefile "${PS5_PATCHES_DIR}/linux.patch" \
			|| die "Failed to apply linux.patch"
	else
		local patch
		local found_patch=0

		shopt -s nullglob
		for patch in "${PS5_PATCHES_DIR}"/*.patch; do
			found_patch=1
			einfo "Applying ${patch}"
			git apply --exclude=Makefile "${patch}" \
				|| die "Failed to apply ${patch}"
		done
		shopt -u nullglob

		[[ ${found_patch} -eq 1 ]] || die "No PS5 kernel patch found in ${PS5_PATCHES_DIR}"
	fi

	cp "${PS5_PATCHES_DIR}/.config" .config \
		|| die "Failed to copy PS5 kernel config"

	default
}

src_configure() {
	:
}

src_compile() {
	:
}

src_install() {
	local kernel_version
	local kernelrelease
	local target_dir

	cd "${LINUX_SRC_DIR}" || die

	kernel_version="$(cat "${WORKDIR}/ps5-kernel-version")" || die

	kernelrelease="$(make -s ARCH=x86 kernelrelease 2>/dev/null || true)"
	[[ -n ${kernelrelease} ]] || kernelrelease="${kernel_version}"

	if [[ ${kernelrelease} != *ps5* ]]; then
		kernelrelease="${kernelrelease}-ps5"
	fi

	target_dir="/usr/src/linux-${kernelrelease}"

	einfo "Installing patched kernel sources to ${target_dir}"

	dodir "${target_dir}"
	cp -a . "${ED%/}${target_dir}/" \
		|| die "Failed to install kernel sources"

	rm -rf "${ED%/}${target_dir}/.git" \
		|| die "Failed to remove git metadata from installed kernel sources"

	# Convenience symlink only; it does not touch /usr/src/linux.
	dosym "${target_dir}" /usr/src/linux-ps5

	insinto /etc/genkernel
	newins "${FILESDIR}/genkernel-ps5.conf" ps5.conf

	insinto /usr/share/ps5-linux
	newins "${FILESDIR}/kexec-gentoo.sh" kexec-gentoo.sh
	fperms 0755 /usr/share/ps5-linux/kexec-gentoo.sh

	dosbin "${FILESDIR}/ps5-install-bootfiles"
}

pkg_postinst() {
	elog "Installed PS5-patched kernel sources."
	elog ""
	elog "Select them, then build with genkernel:"
	elog "  eselect kernel list"
	elog "  eselect kernel set <number-for-linux-*-ps5>"
	elog "  genkernel --kernel-config=/usr/src/linux/.config --no-menuconfig --no-mrproper --oldconfig all"
	elog ""
	elog "After genkernel finished, mount the PS5 Linux boot partition and copy kernel/initrd:"
	elog "  mount /dev/sdX1 /boot/efi"
	elog "  ps5-install-bootfiles /boot/efi"
	elog ""
	elog "Default output names:"
	elog "  /boot/efi/bzImage-gentoo"
	elog "  /boot/efi/initrd-gentoo.img"
	elog ""
	elog "Single-system output names:"
	elog "  ps5-install-bootfiles --single /boot/efi"
	elog "  /boot/efi/bzImage"
	elog "  /boot/efi/initrd.img"
}
