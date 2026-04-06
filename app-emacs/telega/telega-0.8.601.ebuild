# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
NEED_EMACS="27.1"

inherit elisp

# - Version note: server 1.0.0

COMMIT="542774c2779d0d2808c00f9a1c2503fdc0492829"

DESCRIPTION="GNU Emacs telegram client (unofficial)"
HOMEPAGE="https://zevlg.github.io/telega.el"

SRC_URI="https://github.com/zevlg/telega.el/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/telega.el-${COMMIT}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 ~arm arm64 ~x86 ~amd64-linux ~x86-linux"
RESTRICT="mirror bindist"
IUSE="contrib dbus doc geo org stickers tray test texinfo"
REQUIRED_USE="texinfo? ( doc )"
# emerging with geo not tested
SITEFILE="50${PN}-gentoo.el"

DOCS="README.md"

BDEPEND="
	>=app-editors/emacs-29[svg,webp,gif,libxml2]
	>=net-libs/tdlib-1.8.29
	dev-build/make
	virtual/pkgconfig
	doc? ( app-emacs/ellit-org
		   >=app-emacs/htmlize-1.34
		   app-emacs/alert
		   app-emacs/all-the-icons
		   >=app-emacs/compat-28.1.2.2
		   >=app-emacs/dashboard-1.8.1_pre20231201
		   app-emacs/esxml
		   texinfo? ( sys-apps/texinfo ) )
	test? ( >=dev-lang/python-3 app-editors/emacs[svg] )
	tray? ( >=dev-libs/libappindicator-3 )
"

# fixme: tray support will be built if libappindicator is installed,
# regardless of USE
RDEPEND="
	>=app-editors/emacs-29
        >=app-emacs/transient-0.9.0
	>=app-emacs/rainbow-identifiers-0.2.2
	>=app-emacs/visual-fill-column-1.9
	>=net-libs/tdlib-1.8.60
	contrib? ( app-emacs/alert
			   app-emacs/all-the-icons
			   app-emacs/dashboard
			   app-emacs/esxml
			   app-emacs/language-detection )
	dbus? ( app-editors/emacs[dbus] )
	geo? ( app-emacs/geo )
	stickers? ( media-libs/tgs2png )
	tray? ( >=dev-libs/libappindicator-3 )
"

PATCHES=(
	"${FILESDIR}"/${P}-no-proxy-and-file-exist-fix.patch
)

src_prepare() {

	if use doc; then
		eapply "${FILESDIR}/${PN}"-0.8.210-fix-make-doc.patch
		eapply "${FILESDIR}/${PN}"-0.8.217-make-doc-debug.patch
		eapply "${FILESDIR}/${PN}"-0.8.0-fix-make-doc-org-persist.patch
		local themedir="${WORKDIR}/org-html-themes/org"
		mkdir -p ${themedir}
		cp "${FILESDIR}"/theme-readtheorg.setup ${themedir}
		rm docs/index-0.7.2.html
		rm docs/index-release.html
		rm docs/index.html
		rm docs/telega-manual.org
		if use texinfo ; then
			cp "${FILESDIR}"/telega-make-texinfo.el docs
			eapply "${FILESDIR}/${PN}"-0.8.100-doc.patch
		fi
	fi

	if use test; then
		eapply "${FILESDIR}/${PN}"-0.8.0-no-installs-during-test.patch
		eapply "${FILESDIR}/${PN}"-0.8.0-fix-tests-bin-path.patch
		eapply "${FILESDIR}/${PN}"-0.8.254-run-tests-Q.patch
	fi

	default
}

src_compile () {
	elisp_src_compile

	emake telega-server

	use doc && emake -j1 -C docs all && HTML_DOCS=( docs/*.html )
	use doc && use texinfo && \
		elisp-compile docs/telega-make-texinfo.el && \
		${EMACS} -batch -Q -L . -L /usr/share/emacs/site-lisp/org \
				 -l docs/telega-make-texinfo.elc \
				 --eval '(let ((debug-on-error t))
						   (telega--make-texinfo
							"docs/telega-manual.org"))' && \
		ELISP_TEXINFO=( docs/*.texi ) && makeinfo ${ELISP_TEXINFO}

	use geo || rm contrib/telega-live-location.el
	use geo && elisp-compile contrib/telega-live-location.el
	use org && elisp-compile contrib/ol-telega.el

	use contrib && elisp-compile contrib/telega-*.el
}

src_install () {
	elisp_src_install

	# todo: maybe /usr/bin better be determined indirectly by some eclass?
	emake INSTALL_PREFIX="${D}/usr/bin" -C server install

	elisp-install "${PN}" -r etc

	use geo && elisp-install "${PN}" contrib/telega-live-location.{el,elc}
	use geo && rm contrib/telega-live-location*
	use org && elisp-install org contrib/ol-telega.{el,elc}
	rm contrib/ol-telega*
	use contrib && elisp-install "${PN}" contrib/*.{el,elc}
}
