# Copyright 2026 Anoncheg1
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

COMMIT="0e3b3f67d203feb6de1888977a7c850acf7d0731"
DESCRIPTION="C++20 parser and runtime library for Gothic game engine assets"
HOMEPAGE="https://github.com/GothicKit/ZenKit"
SRC_URI="https://github.com/GothicKit/ZenKit/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/ZenKit-${COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="test"
RESTRICT="mirror bindist !test? ( test )"
RDEPEND="
	media-libs/glm
	media-libs/libsquish
"
DEPEND="
	${RDEPEND}
	test? ( dev-cpp/doctest )
"

src_prepare() {
	cmake_src_prepare

	# 1. Neutralize vendor/CMakeLists.txt to properly use system dependencies
	cat << 'EOF' > vendor/CMakeLists.txt
# Handled by Gentoo Portage: Force system dependencies
find_package(glm REQUIRED)

find_library(SQUISH_LIBRARY NAMES squish PATHS "${EPREFIX}/usr/lib64" "${EPREFIX}/usr/lib")
if(NOT SQUISH_LIBRARY)
    message(FATAL_ERROR "Could not find squish library")
endif()

if(NOT TARGET squish)
    add_library(squish UNKNOWN IMPORTED)
    set_target_properties(squish PROPERTIES 
        IMPORTED_LOCATION "${SQUISH_LIBRARY}"
    )
endif()

# Provide compatibility alias for upstream hardcoded target names
if(TARGET glm::glm AND NOT TARGET glm::glm_static)
    add_library(glm::glm_static ALIAS glm::glm)
endif()
EOF

	# 2. Provide a standard doctest main file statically
	cat << 'EOF' > tests/doctest_main.cc
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>
EOF

	# 3. Patch CMakeLists.txt to use system doctest
	sed -i \
		-e 's|include(${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake)|find_package(doctest REQUIRED)\n    include("${doctest_DIR}/doctest.cmake")|g' \
		-e 's|add_executable(test-zenkit ${_ZK_TESTS})|add_executable(test-zenkit ${_ZK_TESTS} tests/doctest_main.cc)|g' \
		-e 's|target_link_libraries(test-zenkit PRIVATE zenkit doctest_with_main)|target_link_libraries(test-zenkit PRIVATE zenkit doctest::doctest)|g' \
		CMakeLists.txt || die

	# 4. Remove the glm installation loop (upstream bug)
	sed -i -E -e '/foreach[[:space:]]*\(lib glm::glm\)/,/endforeach[[:space:]]*\(\)/d' CMakeLists.txt || die

	# 5. Fix missing include/phoenix directory in install targets
	sed -i '\|install(DIRECTORY "include/phoenix" TYPE INCLUDE)|d' CMakeLists.txt || die

	# 6. Add squish include path (Gentoo installs headers in /usr/include/squish/)
	append-cxxflags "-I${EPREFIX}/usr/include/squish"
}
src_configure() {
	local mycmakeargs=(
		-DZK_BUILD_TESTS=$(usex test ON OFF)
		-DZK_BUILD_EXAMPLES=$(usex test ON OFF)
		-DZK_BUILD_SHARED=OFF
		-DZK_ENABLE_ASAN=OFF
		-DZK_ENABLE_DEPRECATION=OFF
	)

	cmake_src_configure
}

src_test() {
        local CMAKE_SKIP_TESTS=(
		"ModelAnimation.load"
	)

	cmake_src_test
}
