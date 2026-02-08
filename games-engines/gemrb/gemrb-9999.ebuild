# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
PYTHON_COMPAT=( python3_{11..13} )
inherit python-any-r1 cmake

if [[ "${PV}" == "9999" ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/gemrb/gemrb"
else
	SRC_URI="https://github.com/gemrb/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz"
fi

DESCRIPTION="Reimplementation of the Infinity engine"
HOMEPAGE="https://gemrb.org/"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS=""
IUSE="+freetype -opengl -truetype"
# REQUIRED_USE="|| ( freetype truetype )"

RDEPEND="
        freetype? ( media-libs/freetype )
        truetype? ( media-fonts/corefonts )
	media-libs/libpng:0
	>=media-libs/libsdl2-2.0[video]
	media-libs/libvorbis
	media-libs/openal[sdl]
	media-libs/sdl2-mixer[vorbis]
	sys-libs/zlib
	${PYTHON_DEPS}"
DEPEND="${RDEPEND}
	virtual/pkgconfig"

src_prepare() {
	if use truetype; then
	        sed -E -i 's|(CustomFontPath[[:space:]]*=[[:space:]]*\")[^\"]*(\")|\1/usr/share/fonts/corefonts\2|' "$WORKDIR"/${P}/gemrb/core/InterfaceConfig.h
	fi
	cmake_src_prepare
}

src_configure() {
	echo $(usex opengl OpenGL None)
	# TODO: SDL2 with OpenGL
	local mycmakeargs=(
		-DDISABLE_WERROR=enabled
		-DOPENGL_BACKEND=$(usex opengl OpenGL None)
		-DSDL_BACKEND=SDL2
		-DRPI=0
		-DUSE_LIBVLC=OFF
		-DUSE_FREETYPE=$(usex freetype ON OFF)
	)

	cmake_src_configure
}
