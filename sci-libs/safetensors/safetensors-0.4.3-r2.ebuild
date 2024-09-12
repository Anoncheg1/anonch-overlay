# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1

CRATES="
	autocfg@1.2.0
	bitflags@1.3.2
	cfg-if@1.0.0
	heck@0.4.1
	indoc@2.0.5
	itoa@1.0.11
	libc@0.2.153
	lock_api@0.4.11
	memmap2@0.9.4
	memoffset@0.9.1
	once_cell@1.19.0
	parking_lot@0.12.1
	parking_lot_core@0.9.9
	portable-atomic@1.6.0
	proc-macro2@1.0.80
	pyo3-build-config@0.21.1
	pyo3-ffi@0.21.1
	pyo3-macros-backend@0.21.1
	pyo3-macros@0.21.1
	pyo3@0.21.1
	quote@1.0.36
	redox_syscall@0.4.1
	ryu@1.0.17
	scopeguard@1.2.0
	serde@1.0.197
	serde_derive@1.0.197
	serde_json@1.0.115
	smallvec@1.13.2
	syn@2.0.59
	target-lexicon@0.12.14
	unicode-ident@1.0.12
	unindent@0.2.3
"
	# windows-targets@0.48.5
	# windows_aarch64_gnullvm@0.48.5
	# windows_aarch64_msvc@0.48.5
	# windows_i686_gnu@0.48.5
	# windows_i686_msvc@0.48.5
	# windows_x86_64_gnu@0.48.5
	# windows_x86_64_gnullvm@0.48.5
	# windows_x86_64_msvc@0.48.5

DISTUTILS_USE_PEP517=maturin
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1 cargo

DESCRIPTION="Simple, safe way to store and distribute tensors"
HOMEPAGE="
	https://pypi.org/project/safetensors/
	https://huggingface.co/
"
SRC_URI="https://github.com/huggingface/${PN}/archive/refs/tags/v${PV}.tar.gz
	-> ${P}.gh.tar.gz
	${CARGO_CRATE_URIS}
"

S="${WORKDIR}"/${P}/bindings/python

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

QA_FLAGS_IGNORED="usr/lib/.*"
RESTRICT="test" #depends on single pkg ( pytorch )

BDEPEND="
	dev-python/setuptools-rust[${PYTHON_USEDEP}]
	test? (
		dev-python/h5py[${PYTHON_USEDEP}]
	)
"

distutils_enable_tests pytest

src_prepare() {
	distutils-r1_src_prepare
	rm tests/test_{tf,paddle,flax}_comparison.py || die
	rm benches/test_{pt,tf,paddle,flax}.py || die
}

filters=( "once_cell"
		  "parking_lot"
		  "lock_api"
		  "serde_json"
		)

src_configure() {
	cargo_src_configure --no-default-features
	# clear default = [ ...] to empty [], to disable defalut features
	rm Cargo.lock # safetensors-0.4.3/safetensors//var/tmp/portage/sci-libs/safetensors-0.4.3-r2/work/safetensors-0.4.3/safetensors
	sed -i -z -E 's/default = \[[^]]*\]/default = \[\]/g' Cargo.toml
	filt=$(for s in "${filters[@]}" ; do echo "$s" ; done  | grep . | tr '\n' '|' )
	filt=${filt:0:${#filt}-1}

	# for f in "${ECARGO_HOME}"/gentoo/* ; do
	# 	if echo "$f" | grep -qvE "$filt" ; then # not have
	# 		# echo $f # /var/tmp/portage/sci-libs/safetensors-0.4.3-r1/work/cargo_home/gentoo/pyo3-0.21.1
	# 		sed -i -z -E 's/default = \[[^]]*\]/default = \[\]/g' "$f"/Cargo.toml
	# 	fi
	# 	# rm "$f"/Cargo.lock
	# done

	# disable windows-targets and redox targets
	# idk why cargo don't see "unix" flag
	f="${ECARGO_HOME}"/gentoo/parking_lot_core-0.9.9/Cargo.toml
	sed '/windows-targets/,+1d' $f > temp_file.txt && mv temp_file.txt $f
	sed '/redox_syscall/,+1d' $f > temp_file.txt && mv temp_file.txt $f

	distutils-r1_src_configure
}

python_compile() {
	# rm Cargo.lock # work/safetensors-0.4.3/bindings/python/Cargo.lock
	# WORKDIR=/var/tmp/portage/sci-libs/safetensors-0.4.3-r2/work
	rm "$WORKDIR"/safetensors-0.4.3/bindings/python/Cargo.lock
	sed -i -z -E 's/default = \[[^]]*\]/default = \[\]/g' "$WORKDIR"/safetensors-0.4.3/bindings/python/Cargo.toml

	cargo_src_compile
	distutils-r1_python_compile
}

src_compile() {
	distutils-r1_src_compile
}

src_install() {
	distutils-r1_src_install
}
