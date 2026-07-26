# Copyright 2026 Anoncheg1
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake virtualx

COMMIT="58477f3eb9a2208dad9f3dae31b98a4b75fcff29"
DESCRIPTION="A modern cross-platform graphics and game engine library"
HOMEPAGE="https://github.com/Try/Tempest"
SRC_URI="https://github.com/Try/Tempest/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Tempest-${COMMIT}"

KEYWORDS="~amd64 ~x86"

LICENSE="MIT"
SLOT="0"

IUSE="audio test vulkan"
# Was not tested: FEATURES=test USE=test emerge tempest
RESTRICT="mirror bindist !test? ( test )"
REQUIRED_USE="test? ( vulkan )"
# audio? ( =media-libs/openal-1.25.2 )

DEPEND="
	dev-libs/stb
	media-libs/libpng:0=
	media-libs/libsquish
	sys-libs/zlib:=
	x11-libs/libX11
	x11-libs/libXcursor
	vulkan? (
           >=media-libs/vulkan-loader-1.4.304.0[X]
           >=dev-util/vulkan-headers-1.4.304.0
)
"
RDEPEND="${DEPEND}"
BDEPEND="
	dev-util/glslang
	virtual/pkgconfig
	test? (
		dev-cpp/gtest
		x11-base/xorg-server[xvfb]
	)
"

CMAKE_USE_DIR="${S}/Engine"

src_prepare() {
	cmake_src_prepare

	# 1. Fix installation target directory paths for Gentoo lib/lib64 architecture
	sed -i \
		-e 's/LIBRARY DESTINATION lib/LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/g' \
		-e 's/ARCHIVE DESTINATION lib/ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/g' \
		Engine/CMakeLists.txt || die "sed failed to fix installation paths"

	# 2. Strip macOS hardcoded toolpaths for glslangValidator
	sed -i 's|find_program(GLSLANGVALIDATOR glslangValidator "/opt/homebrew/bin")|find_program(GLSLANGVALIDATOR glslangValidator REQUIRED)|g' \
		Engine/CMakeLists.txt || die "sed failed to fix glslangValidator path"

	# 3. Fix Vulkan linkage for Gentoo: remove hardcoded SDK paths and use standard find_package
	sed -i '/ENV{VULKAN_SDK}/d' Engine/CMakeLists.txt || die "sed failed to clear VULKAN_SDK paths"

	# Inject find_package(Vulkan REQUIRED) right before the Vulkan block
	sed -i '/^### Vulkan$/i find_package(Vulkan REQUIRED)' Engine/CMakeLists.txt || die "Failed to inject find_package(Vulkan)"

	# Replace bare 'vulkan' and 'vulkan-1' with the proper CMake imported target
	sed -i 's/target_link_libraries(${PROJECT_NAME} PRIVATE vulkan-1)/target_link_libraries(${PROJECT_NAME} PUBLIC Vulkan::Vulkan)/g' Engine/CMakeLists.txt || die
	sed -i 's/target_link_libraries(${PROJECT_NAME} PRIVATE vulkan)/target_link_libraries(${PROJECT_NAME} PUBLIC Vulkan::Vulkan)/g' Engine/CMakeLists.txt || die

	# 5. Strip broken legacy PRIVATE configuration blocks on third-party targets
	sed -i '/target_compile_options(zlibstatic PRIVATE/d' Engine/CMakeLists.txt || die
	sed -i '/target_include_directories(png_static/d' Engine/CMakeLists.txt || die
	sed -i '/target_link_libraries(png_static PRIVATE/d' Engine/CMakeLists.txt || die
	# sed -i '/target_compile_options(OpenAL PRIVATE/d' Engine/CMakeLists.txt || die

	# 6. Neutralize bundled thirdparty subdirectories
	# : > Engine/thirdparty/zlib/CMakeLists.txt || die
	# : > Engine/thirdparty/libpng/CMakeLists.txt || die
	: > Engine/thirdparty/squish/CMakeLists.txt || die # directly used with include
	rm -rf Engine/thirdparty/zlib || die
	rm -rf Engine/thirdparty/libpng || die
 	sed -i '/thirdparty.zlib/d' Engine/CMakeLists.txt || die
	sed -i '/thirdparty.libpng/d' Engine/CMakeLists.txt || die 
	
	# 7. Inject target mappings early using system dependencies
	cat << 'EOF' > "${T}/early_mappings.cmake"
find_package(ZLIB REQUIRED)
add_library(zlibstatic INTERFACE)
target_link_libraries(zlibstatic INTERFACE ZLIB::ZLIB)

find_package(PNG REQUIRED)
add_library(png_static INTERFACE)
target_link_libraries(png_static INTERFACE PNG::PNG)

find_path(SQUISH_INCLUDE_DIR NAMES squish.h HINTS "${EPREFIX}/usr/include/squish" REQUIRED)
find_library(SQUISH_LIBRARY NAMES squish HINTS "${EPREFIX}/usr/lib" "${EPREFIX}/usr/lib64" REQUIRED)
add_library(squish-tempest INTERFACE)
target_link_libraries(squish-tempest INTERFACE ${SQUISH_LIBRARY})
target_include_directories(squish-tempest INTERFACE ${SQUISH_INCLUDE_DIR})
EOF

	sed -i '/### zlib/i include("'${T}/early_mappings.cmake'")' Engine/CMakeLists.txt || die "Failed to inject early mappings"

	# 8. Fix internal header relative paths
	ebegin "Fixing include paths in headers"
	sed -i 's|#include *"../|#include "./|g' Engine/include/Tempest/* || die "Failed to fix header include paths"
	eend $?
}

src_configure() {
	local mycmakeargs=(
		-DTEMPEST_BUILD_SHARED=ON
		-DTEMPEST_BUILD_AUDIO=$(usex audio)
		-DTEMPEST_BUILD_VULKAN=$(usex vulkan)
		-DTEMPEST_BUILD_METAL=OFF
		-DCMAKE_CXX_STANDARD=20
		-DTEMPEST_BUILD_DIRECTX12=OFF
		-DCMAKE_INCLUDE_PATH="${EPREFIX}/usr/include/stb"
	)
	cmake_src_configure

	if use test; then
		local mycmakeargs=(
			-DTEMPEST_BUILD_AUDIO=$(usex audio)
			-DTEMPEST_BUILD_VULKAN=$(usex vulkan)
			-DCMAKE_CXX_STANDARD=20
			-DCMAKE_INCLUDE_PATH="${EPREFIX}/usr/include/stb"
		)
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

src_install() {
	cmake_src_install

	local temp_hdr="${T}/engine_headers"
	mkdir -p "${temp_hdr}" || die
	pushd Engine >/dev/null || die
	rm -rf Engine/thirdparty/squish
	local dir
	for dir in *; do
		if [[ -d "${dir}" && "${dir}" != "include" ]]; then
			cp -r "${dir}" "${temp_hdr}/" || die
		fi
	done
	popd >/dev/null || die

	find "${temp_hdr}" -type f ! -name "*.h" -delete || die

	insinto /usr/include/Tempest
	doins -r "${temp_hdr}"/*
}

src_test() {
	BUILD_DIR="${WORKDIR}/${P}_build_tests" \
		virtx cmake_src_test
}
