# Copyright 2026 Anoncheg
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="OpenGothic - Open source re-implementation of Gothic 2: Night of the Raven"
HOMEPAGE="https://github.com/Try/OpenGothic"
LICENSE="MIT"

SLOT="0"
RESTRICT="mirror bindist"
# OpenGothic: Dec 23, 2025
MY_COMMIT="abf079ead8edf1c4c4a9bad11508680fdb94d7ae"
# ZenKit: 0e3b3f6  Dec 20, 2025 zenkit-20251220
# 0e3b3f67d203feb6de1888977a7c850acf7d0731
# Tempest: Dec 14, 2025
# 580c76c  https://github.com/Try/Tempest/commit/58477f3eb9a2208dad9f3dae31b98a4b75fcff29
# Bullet3: Oct 22, 2025
# https://github.com/bulletphysics/bullet3/commit/63c4d67e337017f9d8b298c900e9aabdb69296e7

SRC_URI="
	https://github.com/Try/OpenGothic/archive/${MY_COMMIT}.tar.gz -> ${P}.tar.gz
	https://github.com/schellingb/TinySoundFont/archive/853a0a171759f1ddba0de1442133a75912bbeffa.tar.gz -> ${PN}-TinySoundFont-853a0a171759f1ddba0de1442133a75912bbeffa.tar.gz
	https://github.com/GothicKit/dmusic/archive/b73b270b94714b8ec8d9d0b2a9f3a5c445da52d1.tar.gz -> ${PN}-dmusic-b73b270b94714b8ec8d9d0b2a9f3a5c445da52d1.tar.gz
"

# Using PV as requested by user
S="${WORKDIR}/OpenGothic-${MY_COMMIT}"

DEPEND="
	=dev-games/tempest-20251214[audio,vulkan]
	=dev-games/zenkit-20251220
	=sci-physics/bullet-20251022
	dev-util/glslang
	media-libs/vulkan-loader
	dev-util/vulkan-headers
	media-libs/libsquish
	media-libs/alsa-lib
	x11-libs/libX11
	x11-libs/libXcursor
"

# media-libs/libglvnd provides GL/EGL dispatch for both Nvidia proprietary and
# Mesa (AMD/Intel/opensource) drivers.
RDEPEND="${DEPEND}
	media-libs/libglvnd
"

BDEPEND="
	dev-build/cmake
	virtual/pkgconfig
"

src_prepare() {
	cmake_src_prepare

	# Extract specific commits for TinySoundFont and dmusic into lib/ directories
	mkdir -p "${S}/lib/TinySoundFont" || die
	tar -xzf "${DISTDIR}/${PN}-TinySoundFont-853a0a171759f1ddba0de1442133a75912bbeffa.tar.gz" \
		--strip-components=1 -C "${S}/lib/TinySoundFont" || die "Failed to extract TinySoundFont"

	mkdir -p "${S}/lib/dmusic" || die
	tar -xzf "${DISTDIR}/${PN}-dmusic-b73b270b94714b8ec8d9d0b2a9f3a5c445da52d1.tar.gz" \
		--strip-components=1 -C "${S}/lib/dmusic" || die "Failed to extract dmusic"

	# Patch CMakeLists.txt to link against installed system dependencies
	sed -i \
		-e 's|add_subdirectory(lib/ZenKit)|find_path(ZENKIT_INCLUDE_DIR NAMES zenkit/World.hh)\nfind_library(ZENKIT_LIBRARY NAMES zenkit)\nfind_library(SQUISH_LIBRARY NAMES squish)\nif(NOT ZENKIT_INCLUDE_DIR OR NOT ZENKIT_LIBRARY OR NOT SQUISH_LIBRARY)\n  message(FATAL_ERROR "ZenKit or Squish not found")\nendif()\nadd_library(zenkit UNKNOWN IMPORTED)\nset_target_properties(zenkit PROPERTIES IMPORTED_LOCATION "${ZENKIT_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${ZENKIT_INCLUDE_DIR}" INTERFACE_LINK_LIBRARIES "${SQUISH_LIBRARY}")|' \
		-e 's|add_subdirectory(lib/Tempest/Engine)|find_path(TEMPEST_INCLUDE_DIR NAMES Tempest)\nfind_library(TEMPEST_LIBRARY NAMES Tempest)\nif(NOT TEMPEST_INCLUDE_DIR OR NOT TEMPEST_LIBRARY)\n  message(FATAL_ERROR "Tempest not found")\nendif()\nadd_library(Tempest UNKNOWN IMPORTED)\nset_target_properties(Tempest PROPERTIES IMPORTED_LOCATION "${TEMPEST_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${TEMPEST_INCLUDE_DIR};${TEMPEST_INCLUDE_DIR}/Tempest/thirdparty/openal-soft/include")|' \
		-e 's|add_subdirectory(lib/bullet3)|find_package(Bullet REQUIRED)\ninclude_directories(${BULLET_INCLUDE_DIRS})|' \
		-e 's|target_link_libraries(${PROJECT_NAME} BulletDynamics BulletCollision LinearMath)|target_link_libraries(${PROJECT_NAME} ${BULLET_LIBRARIES})|' \
		-e '/include_directories(lib\/Tempest\/Engine\/include)/d' \
		-e '/include_directories(lib\/bullet3\/src)/d' \
		-e '/target_compile_options(BulletDynamics/d' \
		-e '/target_compile_options(BulletInverseDynamics/d' \
		-e '/target_compile_options(BulletSoftBody/d' \
		-e '/target_compile_options(Bullet3Common/d' \
		-e '/target_compile_options(BulletCollision/d' \
		-e '/target_compile_options(LinearMath/d' \
		CMakeLists.txt || die "Failed to patch CMakeLists.txt"

	# Fix for: error: ‘zenkit::VInteractiveObject::<unnamed union>::state’ is deprecated
	sed -i 's/\binter\.state\b/inter.state_count/g' game/world/objects/interactive.cpp
}

src_configure() {
        append-libs -lvulkan
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=RelWithDebInfo
		-DBUILD_SHARED_LIBS=OFF
	)
	# Fix for: collect2: error: ld: /usr/lib64/libsquish.so.1.15.1.4: error adding symbols: DSO missing from command line
	# append-ldflags -lsquish

	cmake_src_configure
}

src_install() {
    cmake_src_install

    # Ensure /usr/games exists and move/install the binary there if CMake put it in /usr/bin
    if [[ -f "${ED}/usr/bin/Gothic2Notr" ]]; then
        dodir /usr/games
        mv "${ED}/usr/bin/Gothic2Notr" "${ED}/usr/games/Gothic2Notr" || die
    fi

    # Install the unmodified Gothic2Notr.sh script right next to the binary in /usr/games
    if [[ -f "${S}/scripts/Gothic2Notr.sh" ]]; then
        exeinto /usr/games
        doexe "${S}/scripts/Gothic2Notr.sh"
    fi

    # Optional: Create a symlink in /usr/bin so users can run 'Gothic2Notr' directly from PATH
    dosym ../games/Gothic2Notr.sh /usr/bin/Gothic2Notr

    dodoc README.md CONTRIBUTING.md
}
