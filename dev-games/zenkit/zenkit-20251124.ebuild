# Copyright 2026 Anoncheg1
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic

COMMIT="06abf63bf6a4d4b680f67976b46ea4fd8bba1848"
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

	# 1. Neutralize vendor/CMakeLists.txt to use system dependencies
	cat << 'EOF' > vendor/CMakeLists.txt
# Handled by Gentoo Portage

# Find squish library
find_library(SQUISH_LIBRARY NAMES squish PATHS "${EPREFIX}/usr/lib64" "${EPREFIX}/usr/lib")
if(NOT SQUISH_LIBRARY)
    message(FATAL_ERROR "Could not find squish library")
endif()

if(NOT TARGET squish)
    add_library(squish UNKNOWN IMPORTED)
    set_target_properties(squish PROPERTIES IMPORTED_LOCATION "${SQUISH_LIBRARY}")
endif()
EOF

	# 2. Add find_package calls and create doctest_with_main BEFORE add_subdirectory(vendor)
	sed -i '/add_subdirectory(vendor)/i\find_package(glm REQUIRED)\nif(ZK_BUILD_TESTS)\n    find_package(doctest REQUIRED)\n    \n    # Create doctest_with_main library with implementation\n    if(NOT TARGET doctest_with_main)\n        file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/doctest_main.cc" "#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN\\n#include <doctest/doctest.h>")\n        add_library(doctest_with_main STATIC "${CMAKE_CURRENT_BINARY_DIR}/doctest_main.cc")\n        target_link_libraries(doctest_with_main PUBLIC doctest::doctest)\n    endif()\nendif()' CMakeLists.txt || die

	# 3. Patch root CMakeLists.txt to include doctest's CMake helper script
	sed -i -e 's|include(${doctest_SOURCE_DIR}/scripts/cmake/doctest.cmake)|include("${EPREFIX}/usr/share/doctest/cmake/doctest.cmake" OPTIONAL)\ninclude("${EPREFIX}/usr/lib64/cmake/doctest/doctest.cmake" OPTIONAL)\ninclude("${EPREFIX}/usr/lib/cmake/doctest/doctest.cmake" OPTIONAL)|g' CMakeLists.txt || die

	# 4. "HARSH" FIX: Replace ALL occurrences of glm::glm_static with glm::glm
	sed -i 's/glm::glm_static/glm::glm/g' CMakeLists.txt || die

	# 5. Remove the glm installation loop
	sed -i -E -e '/foreach[[:space:]]*\(lib glm::glm\)/,/endforeach[[:space:]]*\(\)/d' CMakeLists.txt || die

	# 6. "HARSH" FIX: Add squish include path directly to compiler flags
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
	cmake_src_test
}
