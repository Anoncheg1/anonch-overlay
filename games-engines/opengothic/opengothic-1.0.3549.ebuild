# Copyright 2026 Anoncheg
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="OpenGothic - Open source re-implementation of Gothic 2: Night of the Raven"
HOMEPAGE="https://github.com/Try/OpenGothic"
LICENSE="MIT"

SLOT="0"
RESTRICT="mirror bindist"

MY_COMMIT="abf079ead8edf1c4c4a9bad11508680fdb94d7ae"
# OpenGothic: Dec 23, 2025
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

	# 1. Extract specific commits for TinySoundFont and dmusic into lib/ directories
	mkdir -p "${S}/lib/TinySoundFont" || die
	tar -xzf "${DISTDIR}/${PN}-TinySoundFont-853a0a171759f1ddba0de1442133a75912bbeffa.tar.gz" \
		--strip-components=1 -C "${S}/lib/TinySoundFont" || die "Failed to extract TinySoundFont"

	mkdir -p "${S}/lib/dmusic" || die
	tar -xzf "${DISTDIR}/${PN}-dmusic-b73b270b94714b8ec8d9d0b2a9f3a5c445da52d1.tar.gz" \
		--strip-components=1 -C "${S}/lib/dmusic" || die "Failed to extract dmusic"

	# 2. Remove bundled submodule builds for ZenKit, Tempest, and Bullet
	# We use a simple range deletion based on unique markers in the CMakeLists.txt
	sed -i \
		-e '/^add_subdirectory(lib\/ZenKit)/,/^target_link_libraries(${PROJECT_NAME} zenkit)$/d' \
		-e '/^add_subdirectory(lib\/Tempest\/Engine)/,/^target_link_libraries(${PROJECT_NAME} Tempest)$/d' \
		-e '/^add_subdirectory(lib\/bullet3)/,/^target_link_libraries(${PROJECT_NAME} BulletDynamics BulletCollision LinearMath)$/d' \
		CMakeLists.txt || die "Failed to remove bundled dependencies"

	# 3. Append system dependency lookup logic to the end of CMakeLists.txt
	cat >> CMakeLists.txt << 'EOF'

## System Dependencies Replacement

# ZenKit
find_path(ZENKIT_INCLUDE_DIR NAMES zenkit/World.hh)
find_library(ZENKIT_LIBRARY NAMES zenkit)
find_library(SQUISH_LIBRARY NAMES squish)
if(NOT ZENKIT_INCLUDE_DIR OR NOT ZENKIT_LIBRARY OR NOT SQUISH_LIBRARY)
  message(FATAL_ERROR "ZenKit or Squish not found")
endif()
add_library(zenkit IMPORTED UNKNOWN)
set_target_properties(zenkit PROPERTIES IMPORTED_LOCATION "${ZENKIT_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${ZENKIT_INCLUDE_DIR}" INTERFACE_LINK_LIBRARIES "${SQUISH_LIBRARY}")
target_link_libraries(${PROJECT_NAME} zenkit)

# Tempest
find_path(TEMPEST_INCLUDE_DIR NAMES Tempest)
find_library(TEMPEST_LIBRARY NAMES Tempest)
find_library(OPENAL_LIBRARY NAMES openal)
if(NOT TEMPEST_INCLUDE_DIR OR NOT TEMPEST_LIBRARY OR NOT OPENAL_LIBRARY)
  message(FATAL_ERROR "Tempest or OpenAL not found")
endif()
add_library(Tempest IMPORTED UNKNOWN)
set_target_properties(Tempest PROPERTIES IMPORTED_LOCATION "${TEMPEST_LIBRARY}" INTERFACE_INCLUDE_DIRECTORIES "${TEMPEST_INCLUDE_DIR}" INTERFACE_LINK_LIBRARIES "${OPENAL_LIBRARY}")
target_link_libraries(${PROJECT_NAME} Tempest)

# Bullet Physics
find_package(Bullet REQUIRED)
include_directories(${BULLET_INCLUDE_DIRS})
target_link_libraries(${PROJECT_NAME} ${BULLET_LIBRARIES})
EOF

	# 4. Fix for: error: ‘zenkit::VInteractiveObject::<unnamed union>::state’ is deprecated
	sed -i 's/\binter\.state\b/inter.state_count/g' game/world/objects/interactive.cpp || die "Failed to patch interactive.cpp"
}

src_configure() {
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=RelWithDebInfo
		-DBUILD_SHARED_LIBS=OFF
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Move binary to /usr/games as per Gentoo policy for games
	dodir /usr/games
	if [[ -f "${ED}/usr/bin/Gothic2Notr" ]]; then
		mv "${ED}/usr/bin/Gothic2Notr" "${ED}/usr/games/" || die "Failed to move Gothic2Notr binary"
	fi

	# Install the launch script
	if [[ -f "${S}/scripts/Gothic2Notr.sh" ]]; then
		exeinto /usr/games
		doexe "${S}/scripts/Gothic2Notr.sh"
	fi

	# Symlink for PATH (EAPI 8 relative symlink)
	dosym -r /usr/games/Gothic2Notr.sh /usr/bin/Gothic2Notr

	dodoc README.md CONTRIBUTING.md
}
