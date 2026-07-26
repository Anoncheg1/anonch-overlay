- sci-ml/safetensors-0.5.3-r88881 - refined dependencies with working tests
- sci-ml/tokenizers/tokenizers-0.21.1-r88881 - refined dependencies, tests not working
- sci-libs/unhubbed-transformers - disable tokenizers, pyyaml, huggingface_hub dependencies
- sys-kernel/rtl88x2bu-driver - Driver for WIFI USB RTL8822BU and install script (not require firmware)
- games-engines/gemrb-0.9.4 - Baldur's Gate 1 and 2, Icewind Dale 1 and 2, Planescape: Torment and their mods.
- net-libs/gumbo - HTML5 parsing library in C. - added Python bindings
- app-misc/heaviest - Own daemon and command that allow to get most heavy process name for reccent several minutes.
- app-misc/kbdtimeout - Own daemon that allow to execute command (for ex. block PC) if no keys was pressed for some time.
- app-misc/keyd - remapping keys in X11 and Wayland per applications and global.
- app-text/opendetex - removing TeX and LaTeX
- Telega - Unoffical Telegram client. Include:  net-libs/tdlib, app-emacs/rainbow-identifiers, app-emacs/visual-fill-column
- OpenGothic 2025 v1.0.3549: dev-games/zenkit, dev-games/tempest, games-engines/opengothic


Removed
- sci-libs/caffe2-2.4.0-r2  - disable sci-libs/kineto, +numpy -> numpy

# OpenGothic
Install binary and script to `/usr/games/Gothic2Notr` and `/usr/games/Gothic2Notr.sh` with `Gothic2Notr` in `/usr/bin` pointing to `Gothic2Notr.sh`.

To run game use: `/usr/games/Gothic2Notr.sh -g "~/Gothic-II"`

If you have GOG.com exe installer, you may extract it with help of `app-arch/innoextract`.
```sh
innoextract --exclude-temp --gog -d "~/Gothic-II" ./setup_gothic_2_gold_2.7_(14553).exe
```

OpenGothic stores save files in its working directory (the folder containing the game executable) - `save_slot_1.sav, save_slot_2.sav`.

To set FPS limit, add to `~/Gothic-II/Gothic.ini`
```conf
[ENGINE]
zMaxFPS=60
```

Try additional graphic enhancements: `-rt 1 -aa 2 -ms 1 -gi 1`

You may try to optimize game with GCC flags, see [GentooWiki:Per-package_environment_variables](https://wiki.gentoo.org/wiki/Handbook:AMD64/Portage/Advanced#Per-package_environment_variables)

## Note on Ebuild
In Tempest, I was able to use system libraries (libpng, libsquish, zlib) as replacements for the source libraries. However, for Squish, the built-in header files are still used.

For OpenAL, it is not possible to use the `media-libs/openal` library because it relies on the rare option `-DAL_ALEXT_PROTOTYPES`.

Tempest is installed as a shared library instead of being built as a single one, due to its complexity, which requires a separate Ebuild file.

Tempest has a very unusual folder containing header files that act as proxies, which is why we use some strange logic to remove all except `.h` files.

# Donate
- BTC (Bitcoin) address: 1CcDWSQ2vgqv5LxZuWaHGW52B9fkT5io25

![](https://raw.githubusercontent.com/Anoncheg1/public-share/refs/heads/main/BTC-1CcDWSQ2vgqv5LxZuWaHGW52B9fkT5io25.png)

- USDT (Tether TRX-TRON) address: TVoXfYMkVYLnQZV3mGZ6GvmumuBfGsZzsN

![](https://raw.githubusercontent.com/Anoncheg1/public-share/refs/heads/main/USDT-TVoXfYMkVYLnQZV3mGZ6GvmumuBfGsZzsN.png)

- TON (Telegram) address: UQC8rjJFCHQkfdp7KmCkTZCb5dGzLFYe2TzsiZpfsnyTFt9D
