# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
# python3_15 does not exist in the tree yet; keeping only real versions
# avoids a QA warning. Re-add 15 when the interpreter lands.
PYTHON_COMPAT=( python3_{12..14} )
inherit python-single-r1 cmake

COMMIT="fb5bf5625b1c8c385b073e52c4b73b9ae2f1f60c"
SRC_URI="https://github.com/gemrb/gemrb/archive/${COMMIT}.tar.gz
	-> ${PN}-${COMMIT}.tar.gz"
S="${WORKDIR}/gemrb-${COMMIT}"

DESCRIPTION="Reimplementation of the Infinity engine"
HOMEPAGE="https://gemrb.org/"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

# IUSE -- each flag is verified to control an existing CMake option or a
# legitimate Gentoo-side concern:
#
#  freetype  -> -DUSE_FREETYPE           (upstream default ON)
#  openal    -> -DUSE_OPENAL             (upstream default ON)
#  png       -> -DUSE_PNG                (upstream default ON)
#  sdlmixer  -> -DUSE_SDLMIXER           (upstream default ON)
#  vorbis    -> -DUSE_VORBIS             (upstream default ON)
#  vlc       -> -DUSE_LIBVLC             (upstream default ON, but we make it
#                                         opt-in because it pulls the full VLC
#                                         stack; a Gentoo-side deviation)
#  opengl    -> -DOPENGL_BACKEND=OpenGL  (upstream default None)
#  truetype  -> no CMake option; installs media-fonts/corefonts and patches
#               the built-in default font path to that directory
#
# Deliberately NOT exposed (hardcoded for good reason):
#  USE_TESTS       -> needs GTest, only relevant to upstream CI
#  USE_TRACY       -> pulls its source via FetchContent (network in sandbox)
#  STATIC_LINK     -> Gentoo policy is dynamic linking
#  SKIP_DEMO_DATA  -> on, so we do not ship upstream's test resources
#  SDL_BACKEND     -> forced to SDL2 (SDL1.2 is dead upstream and in Gentoo)
IUSE="+freetype +openal +png +sdlmixer +truetype +vorbis +opengl vlc"

# truetype without freetype is nonsensical: we would install corefonts and
# patch the default font path, but the TTF plugin that reads from that path
# would not be built.
REQUIRED_USE="truetype? ( freetype )"

# Dependency notes:
#  * virtual/libiconv is a new hard requirement: cmake/FindDependencies.cmake
#    does find_package(Iconv REQUIRED) and gemrb_core links against it.
#    No-op on glibc, pulls dev-libs/libiconv on musl.
#  * media-libs/libpng is gated behind USE=png (CMake option USE_PNG).
#  * media-video/vlc ships its own development headers; there is no separate
#    -dev split on Gentoo, so no USE sub-selector is needed. Note that
#    USE=vlc may not configure cleanly against every VLC configuration;
#    cmake/modules/FindLIBVLC.cmake has not been verified on Gentoo.
#  * media-libs/openal provides <AL/efx.h>; EFX is enabled automatically when
#    present. We deliberately do NOT enable openal[sdl]: GemRB talks to AL/ALC
#    directly and does not route through OpenAL's SDL audio backend.
#  * media-libs/libsdl2 has SLOT="0" with no sub-slot; use :0 not :0=.
#    The old "opengl" USE flag on libsdl2 no longer exists, so we do not
#    request it here -- SDL2's GL surface support is always built.
#  * media-libs/sdl2-mixer is gated behind USE=sdlmixer. Users who want Ogg
#    playback through the SDLMixer backend specifically (rather than through
#    GemRB's own VorbisFile plugin) should enable media-libs/sdl2-mixer[vorbis]
#    themselves; we deliberately do not couple that here.
RDEPEND="
	freetype? ( media-libs/freetype:2 )
	truetype? ( media-fonts/corefonts )
	media-libs/libsdl2:0
	sdlmixer? ( media-libs/sdl2-mixer )
	openal? ( media-libs/openal )
	png? ( media-libs/libpng:0= )
	vorbis? ( media-libs/libvorbis )
	vlc? ( media-video/vlc )
	sys-libs/zlib
	virtual/libiconv
	${PYTHON_DEPS}"
DEPEND="${RDEPEND}
	virtual/pkgconfig"

src_prepare() {
	if use truetype; then
		# CoreSettings::CustomFontPath has an in-class default of
		# "/usr/share/fonts/TTF" (a Debian-ism). Repoint that default at the
		# Gentoo corefonts location. User overrides in GemRB.cfg still win at
		# runtime, because InterfaceConfig.cpp uses CONFIG_PATH() to pick up
		# the value from the config file when present.
		sed -E -i \
			's|(CustomFontPath[[:space:]]*=[[:space:]]*")[^"]*(")|\1/usr/share/fonts/corefonts\2|' \
			"${S}/gemrb/core/InterfaceConfig.h" || die "truetype sed failed"
	fi
	cmake_src_prepare
}

src_configure() {
	local mycmakeargs=(
		# Gentoo: never fail the build on warnings introduced by new
		# compilers or arches.
		# -DDISABLE_WERROR=ON

		# SDL 1.2 is dead upstream and in Gentoo; only SDL2 is supported.
		# Passing SDL2 explicitly avoids any Auto resolution surprises.
		-DSDL_BACKEND=SDL2

		# CMake accepts None | OpenGL | GLES. We only expose desktop
		# OpenGL; GLES is embedded-only and would need different GL
		# dependencies.
		-DOPENGL_BACKEND=$(usex opengl OpenGL None)

		# CONFIGURE_PYTHON() (in cmake/modules/, not shown) is not visible
		# in the provided sources; the PYTHON_VERSION docstring only shows
		# "Auto", "3", and "3.6" as examples. We pass "Auto" and rely on
		# python-utils-r1 exporting Python3_EXECUTABLE / EPYTHON so CMake's
		# find_package(Python3) picks the interpreter selected by
		# PYTHON_COMPAT. If this turns out to be wrong, the correct fix
		# belongs in cmake/modules/ (CONFIGURE_PYTHON), not in the ebuild.
		-DPYTHON_VERSION=Auto

		# Feature toggles mirroring IUSE.
		-DUSE_FREETYPE=$(usex freetype ON OFF)
		-DUSE_OPENAL=$(usex openal ON OFF)
		-DUSE_PNG=$(usex png ON OFF)
		-DUSE_SDLMIXER=$(usex sdlmixer ON OFF)
		-DUSE_VORBIS=$(usex vorbis ON OFF)
		-DUSE_LIBVLC=$(usex vlc ON OFF)

		# Never enable tests (they need GTest) or Tracy (it pulls its source
		# via CMake FetchContent, i.e. a network fetch inside the sandbox,
		# which would fail the build).
		-DUSE_TESTS=OFF
		-DUSE_TRACY=OFF

		# Do not install the demo resource tree by default; the demo is
		# upstream's test data, not something distro users expect. Users can
		# override via MYCMAKEARGS if they want it.
		-DSKIP_DEMO_DATA=ON

		# Gentoo policy: dynamic linking, not static.
		-DSTATIC_LINK=OFF
	)

	cmake_src_configure
}
