# Copyright 2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
DESCRIPTION="Removes TeX and LaTeX constructs from text source (detex, delatex)"
HOMEPAGE="https://github.com/pkubowicz/opendetex"
SRC_URI="https://github.com/pkubowicz/opendetex/archive/refs/tags/v2.8.11.tar.gz -> opendetex-2.8.11.tar.gz"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"

IUSE="test"
BDEPEND="sys-devel/flex
    test? ( dev-lang/perl dev-debug/valgrind )"

DOCS=( README INSTALL ChangeLog COPYRIGHT )
S="${WORKDIR}/opendetex-2.8.11"

src_prepare() {
    default
    # fix installation paths for Gentoo FHS
    sed -i \
        -e 's:/usr/local/bin:/usr/bin:' \
        -e 's:/usr/local/share/man/man1:/usr/share/man/man1:' \
        Makefile || die
}

src_compile() {
    emake
}

src_install() {
    # Install binaries
    dobin detex
    dosym detex /usr/bin/delatex  # Create delatex symlink

    # Install manpage
    doman detex.1

    # Documentation
    dodoc "${DOCS[@]}"
}


src_test() {
    if [[ -x /usr/bin/valgrind ]]; then
        einfo "Running upstream tests with valgrind"
        "${EPREFIX}/usr/bin/perl" test.pl --valgrind || die "Upstream tests (valgrind) failed"
    else
        einfo "Running upstream tests"
        "${EPREFIX}/usr/bin/perl" test.pl || die "Upstream tests failed"
    fi
}
