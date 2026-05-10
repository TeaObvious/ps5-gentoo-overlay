# Copyright 2026
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3 toolchain-funcs systemd

DESCRIPTION="Linux control and M.2 helper tools for PlayStation 5"
HOMEPAGE="https://github.com/ps5-linux/ps5-linux-tools"
EGIT_REPO_URI="https://github.com/ps5-linux/ps5-linux-tools.git"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS=""
IUSE="systemd openrc"
PROPERTIES="live"

BDEPEND="
	dev-build/make
	dev-vcs/git
"

RDEPEND="
	sys-apps/kexec-tools
	sys-apps/util-linux
	sys-fs/e2fsprogs
	sys-libs/zlib
	openrc? ( sys-apps/openrc )
	systemd? ( sys-apps/systemd )
"

src_prepare() {
	default

	# Upstream installer uses /usr/local/sbin; Gentoo packages install to /usr/sbin.
	if [[ -d systemd ]]; then
		sed -i \
			-e 's:/usr/local/sbin/ps5_control:/usr/sbin/ps5_control:g' \
			systemd/*.service \
			|| die
	fi
}

src_compile() {
	emake \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LDFLAGS="${LDFLAGS} -lz"
}

src_install() {
	dosbin ps5_control
	dosbin m2_init

	exeinto /usr/sbin
	newexe m2_exec.sh ps5-m2-exec
	newexe m2_install.sh ps5-m2-install

	if use systemd; then
		systemd_dounit systemd/ps5fan.service
		systemd_dounit systemd/ps5boost.service
	fi

	if use openrc; then
		newinitd "${FILESDIR}/ps5fan.initd" ps5fan
		newinitd "${FILESDIR}/ps5boost.initd" ps5boost
	fi
}

pkg_postinst() {
	elog "Installed PS5 tools:"
	elog "  /usr/sbin/ps5_control"
	elog "  /usr/sbin/m2_init"
	elog "  /usr/sbin/ps5-m2-exec"
	elog "  /usr/sbin/ps5-m2-install"
	elog ""
	elog "Fan/boost services are installed only when USE=systemd or USE=openrc is enabled."
	elog ""
	elog "For OpenRC:"
	elog "  rc-update add ps5fan default"
	elog "  rc-update add ps5boost default"
	elog ""
	elog "For systemd:"
	elog "  systemctl enable --now ps5fan.service ps5boost.service"
}
