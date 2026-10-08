# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit cmake
DESCRIPTION="Fallout 1 Community Edition - native engine re-implementation"
HOMEPAGE="https://github.com/alexbatalov/fallout1-ce"

# Upstream commit of fallout1-ce itself.
COMMIT="0609bcfd0ec40ff0571d0f57fab2821eb461dc8b"

# adecode is pulled by upstream via FetchContent from
# third_party/adecode/CMakeLists.txt at ${COMMIT}. Keep in sync.
ADECODE_COMMIT="e4a8b0f3b66826e0b7779a25d79df8497f8f8087"

# fpattern is pulled via FetchContent from
# third_party/fpattern/CMakeLists.txt at ${COMMIT}. Keep in sync.
FPATTERN_COMMIT="8523173ec252c3b796fcdfca0fcc6329642fbbe3"

SRC_URI="
	https://github.com/alexbatalov/fallout1-ce/archive/${COMMIT}.tar.gz
		-> ${PN}-${COMMIT}.tar.gz
	https://github.com/alexbatalov/adecode/archive/${ADECODE_COMMIT}.tar.gz
		-> adecode-${ADECODE_COMMIT}.tar.gz
	https://github.com/alexbatalov/fpattern/archive/${FPATTERN_COMMIT}.tar.gz
		-> fpattern-${FPATTERN_COMMIT}.tar.gz
"

S="${WORKDIR}/fallout1-ce-${COMMIT}"
LICENSE="Sustainable-Use"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

RDEPEND="
	media-libs/libsdl2
	media-libs/sdl2-mixer
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-build/cmake
"

src_unpack() {
	default

	# FetchContent looks up FETCHCONTENT_SOURCE_DIR_<UPPERNAME>; the exact
	# extraction directory name is irrelevant as long as we point at it,
	# but we rename for clarity and to avoid collisions.
	mv "${WORKDIR}/adecode-${ADECODE_COMMIT}" \
		"${WORKDIR}/adecode-${ADECODE_COMMIT}.src" || die
	mv "${WORKDIR}/fpattern-${FPATTERN_COMMIT}" \
		"${WORKDIR}/fpattern-${FPATTERN_COMMIT}.src" || die
}

src_configure() {
	# Upstream calls add_subdirectory("third_party/adecode") etc., but the
	# tarball does not contain the submodule payload. Create empty dirs so
	# add_subdirectory() succeeds; FetchContent will use our overrides.
	mkdir -p third_party/adecode third_party/fpattern || die

	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release

		# --- THE FIX -------------------------------------------------------
		# adecode/CMakeLists.txt declares add_library(adecode-static ...)
		# WITHOUT STATIC/SHARED. CMake then honours BUILD_SHARED_LIBS. The
		# default of that variable is OFF, but some profiles/toolchains set
		# it ON via CMAKE_TOOLCHAIN_FILE, and *upstream's own SDL2 shim*
		# can enable it. Force OFF so libadecode is a static archive and
		# gets linked into fallout-ce, eliminating the runtime .so lookup
		# for libadecode-static.so.
		-DBUILD_SHARED_LIBS=OFF

		# FetchContent overrides: use our unpacked sources, never the net.
		-DFETCHCONTENT_SOURCE_DIR_ADECODE="${WORKDIR}/adecode-${ADECODE_COMMIT}.src"
		-DFETCHCONTENT_SOURCE_DIR_FPATTERN="${WORKDIR}/fpattern-${FPATTERN_COMMIT}.src"
		-DFETCHCONTENT_FULLY_DISCONNECTED=ON

		# Belt-and-braces: fail loudly if anything still tries to fetch.
		-DFETCHCONTENT_UPDATES_DISCONNECTED=ON
	)

	cmake_src_configure
}

src_compile() {
	cmake_src_compile

	# Sanity check: we asked for a static adecode. If a .so slipped out,
	# something overrode BUILD_SHARED_LIBS and the installed binary would
	# be broken at runtime. Fail the build instead.
	if find "${BUILD_DIR}" -name 'libadecode*.so*' -print -quit | grep -q . ; then
		die "libadecode was built as a shared library; BUILD_SHARED_LIBS is not OFF"
	fi
}

src_install() {
	# The executable is at the build root (no RUNTIME_OUTPUT_DIRECTORY
	# override in upstream CMakeLists.txt). Try the common locations so a
	# future upstream change to RUNTIME_OUTPUT_DIRECTORY does not silently
	# break the install.
	local exe
	for candidate in \
		"${BUILD_DIR}/fallout-ce" \
		"${BUILD_DIR}/bin/fallout-ce" \
		"${BUILD_DIR}/src/fallout-ce"
	do
		if [[ -x ${candidate} ]]; then
			exe=${candidate}
			break
		fi
	done
	[[ -n ${exe} ]] || die "could not locate the fallout-ce executable in ${BUILD_DIR}"

	dobin "${exe}"
	einstalldocs
}

pkg_postinst() {
	elog
	elog "Fallout 1 Community Edition requires the original Fallout 1 game data"
	elog "(MASTER.DAT, CRITTER.DAT, DATA/ directory, etc.) in current directory to run."
	elog "/usr/bin/fallout-ce should be run from"
	elog "a directory containing the data files."
	elog "/usr/bin/fallout-ce fail silently with return code 1 if data files "
	elog "not found in current directoyr. See:"
	elog " https://github.com/alexbatalov/fallout1-ce#usage"
	elog
}
