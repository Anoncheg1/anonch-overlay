# Copyright 2025-2026 Anoncheg1
# Distributed under the terms of the GNU Affero General Public License v3.0 (AGPL-3.0)

EAPI=8

DESCRIPTION="Daemon and command to identify the heaviest CPU process over recent minutes"
HOMEPAGE="https://github.com/Anoncheg1/anonch-overlay"
# No SRC_URI is needed since all source files are local in the files/ directory
LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="amd64 arm64 x86"
RESTRICT="fetch"

# Tell Portage that the source directory is the work directory itself,
# not a subdirectory named after the package version (which doesn't exist).
S="${WORKDIR}"


src_install() {
    newbin "${FILESDIR}"/heaviest-get.py heaviest-get
    newbin "${FILESDIR}"/heaviest-cpu-daemon.sh heaviest-cpu-daemon

    chmod +x "${D}/usr/bin/heaviest-get"
    chmod +x "${D}/usr/bin/heaviest-cpu-daemon"

    newinitd "${FILESDIR}/heaviest.initd" "heaviest"

    keepdir /var/lib/heaviest
}
