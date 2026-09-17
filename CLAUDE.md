# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A portable Blender install plus the user's Blender config, tracked as one repo. There is no
build, lint, or test suite. Blender itself is a git-ignored download in `blender/`; the tracked
payload is a handful of shell scripts, one Python setup script, and the `portable/` config tree.
macOS only (uses `hdiutil`, `ditto`, `/Applications`).

## Commands

```sh
./install.sh                     # download/upgrade latest Blender into blender/, link config, install extensions.txt (idempotent, re-run to upgrade)
bin/blender                      # launch the portable Blender (thin exec wrapper; passes args through)
bin/blender --python setup.py    # regenerate startup.blend + userpref.blend from scratch (opens a window briefly, exits itself)
bin/keymap-export                # dump the full active keymap to portable/scripts/presets/keyconfig/dcc.py (opens a window ~1s)
bin/blender -b --python-expr "..."   # run any bpy snippet headless
```

## How the pieces fit

- **Portable config via symlink.** `install.sh` symlinks `blender/Blender.app/Contents/Resources/portable` to `./portable`. Blender treats a `portable/` dir next to its resources as its config root, so everything it saves (prefs, startup file, keymap presets, extensions) lands in the repo and shows in `git status`. `.gitignore` filters the noise (`extensions/`, `cache/`, `recent-*.txt`, `platform_support.txt`, `scripts/addons/`).
- **The real config is binary.** `portable/config/startup.blend` and `userpref.blend` are the source of truth for scene/UI/prefs and are committed as binaries. They are *generated* by `setup.py`; edit `setup.py` and re-run it rather than hand-tweaking and saving from the UI when the change should be reproducible. Commit both `.blend` files after re-running.
- **`setup.py` runs inside Blender's event loop.** Preference and data changes happen at import, but area/workspace edits need the workspace live in a window, so the script registers a `bpy.app.timers` callback that visits each workspace one tick at a time, then saves prefs + homefile and calls `os._exit(0)` to dodge the quit prompt. New UI tweaks belong inside `step()`, not at top level. It must be run via `bin/blender --python setup.py` *with* a window (not `-b`).
- **Extensions are declared, not committed.** `extensions.txt` lists `blender_org <id>` or `github <owner/repo>` lines; `install.sh` installs them into the ignored `portable/extensions/`. GitHub entries prefer the latest release `.zip` asset and fall back to the repo zipball, which it re-zips so the top-level dir is a valid module name.
- **Download source.** `install.sh` pulls from the `mirrors.dotsrc.org` Blender mirror because `download.blender.org` sits behind a Cloudflare JS challenge. It resolves "latest" by scraping the mirror's directory listing and skips the download if `blender/VERSION` already matches.
- **Keymap.** `dcc.py` is a full keymap preset (Industry Compatible plus our edits) and the source of truth; `setup.py` activates it. Workflow: change keys in Preferences > Keymap, run `bin/keymap-export`, commit `dcc.py` + `userpref.blend`. No per-hotkey Python. Export must run windowed: headless Blender never activates the preset, so it would export the default keymap.

## Conventions

- Scripts are deliberately tiny and comment-dense; keep that style. Explain *why* (e.g. the mirror choice, the zipball rename) in a trailing comment rather than adding structure.
- `portable/config/bookmarks.txt` is git-ignored: it holds machine-local recent paths, not config.
