# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake virtualx

DESCRIPTION="A modern cross-platform graphics and game engine library"
HOMEPAGE="https://github.com/Try/Tempest"

if [[ ${PV} == 9999 ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Try/Tempest.git"
else
	SRC_URI="https://github.com/Try/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="MIT"
SLOT="0"
IUSE="audio test vulkan"
RESTRICT="!test? ( test )"

DEPEND="
	x11-libs/libX11
	x11-libs/libXcursor
	vulkan? ( media-libs/vulkan-loader )
"
RDEPEND="${DEPEND}"

# dev-cpp/gtest provides source trees in /usr/src/gtest used for static testing bindings
BDEPEND="
	dev-util/glslang
	test? ( dev-cpp/gtest )
"

CMAKE_USE_DIR="${S}/Engine"

src_prepare() {
	cmake_src_prepare

	# Fix hardcoded 'lib' destination to respect Gentoo's lib/lib64 structure
	sed -i \
		-e 's/LIBRARY DESTINATION lib/LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/g' \
		-e 's/ARCHIVE DESTINATION lib/ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/g' \
		Engine/CMakeLists.txt || die "sed failed to fix installation paths"
}

src_configure() {
	if use vulkan; then
		export VULKAN_SDK="${EPREFIX}/usr"
	fi

	local mycmakeargs=(
		-DTEMPEST_BUILD_SHARED=ON
		-DTEMPEST_BUILD_AUDIO=$(usex audio)
		-DTEMPEST_BUILD_VULKAN=$(usex vulkan)
		-DTEMPEST_BUILD_METAL=OFF
		-DTEMPEST_BUILD_DIRECTX12=OFF
		-DGLSLANGVALIDATOR="${EPREFIX}/usr/bin/glslangValidator"
	)

	cmake_src_configure

	# Configure the separate test suite context if requested
	if use test; then
		local mycmakeargs=(
			-DGLSLANGVALIDATOR="${EPREFIX}/usr/bin/glslangValidator"
			-DTEMPEST_BUILD_AUDIO=$(usex audio)
			-DTEMPEST_BUILD_VULKAN=$(usex vulkan)
		)
		# Map directly to the Gentoo system copy of GoogleTest sources
		export GOOGLETEST_DIR="${EPREFIX}/usr/src/gtest"

		BUILD_DIR="${WORKDIR}/${P}_build_tests" \
		CMAKE_USE_DIR="${S}/Tests/tests" \
		cmake_src_configure
	fi
}

src_compile() {
	cmake_src_compile

	if use test; then
		BUILD_DIR="${WORKDIR}/${P}_build_tests" \
		cmake_src_compile
	fi
}

src_test() {
	# Run tests in a virtual framebuffer context to prevent X11 display context collisions
	BUILD_DIR="${WORKDIR}/${P}_build_tests" \
	virtx cmake_src_test
}
