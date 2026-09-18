# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A portable Blender install plus the user's Blender config, tracked as one repo. There is no
build, lint, or test suite. Blender itself is a git-ignored download in `blender/`; the tracked
payload is a handful of shell scripts, one Python setup script, and the `portable/` config tree.
macOS only (uses `hdiutil`, `ditto`, `/Applications`).

**Who it's for: an environment artist.** Weigh every config, hotkey, and extension decision
against environment-art work: modeling, placement, snapping, and asset workflows. Leave out
animation features (keyframes, timeline, frame stepping), as `setup.py` already does by dropping
the Animation workspace and closing timelines. The user's background is 3ds Max and Modo (not
Maya); Industry Compatible is the keymap base only because it is the closest stock preset. Never
justify a setting or key by "that's how Maya/Max/Modo does it"; justify it by what it does for
environment work. Target engine is Unreal (scene displays centimeters, 1 BU stays 1 m).

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
- **Layout's bottom area is the Asset Browser** (set in `setup.py`'s `step()` where other workspaces close their timeline). Node Wrangler is a bundled legacy add-on, enabled from `setup.py`, not `extensions.txt`.
- **Extensions are declared, not committed.** `extensions.txt` lists `blender_org <id>`, `github <owner/repo>`, or `forgejo <host/owner/repo>` lines; `install.sh` installs them into the ignored `portable/extensions/`. GitHub/Forgejo entries (Forgejo serves the same releases API under `/api/v1`) prefer the latest release `.zip` asset and fall back to the repo zipball, which it re-zips so the top-level dir is a valid module name.
- **Blender MCP.** `extensions.txt` installs the official Blender Lab MCP add-on (`forgejo projects.blender.org/lab/blender_mcp`), which autostarts a socket on localhost:9876 when Blender opens (needs online access, set in `setup.py`). `install.sh` step 6 removes and re-adds the `blender` server at Claude Code user scope (skipped without `claude` + `uvx`), run via `uvx` from upstream git so it's never vendored. Blender must be open for the tools to work.
- **Download source.** `install.sh` pulls from the `mirrors.dotsrc.org` Blender mirror because `download.blender.org` sits behind a Cloudflare JS challenge. It resolves "latest" by scraping the mirror's directory listing and skips the download if `blender/VERSION` already matches. It also symlinks `/Applications/Blender.app` to the repo copy, but only if that path is absent or already a symlink.
- **Keymap.** `dcc.py` is a full keymap preset (Industry Compatible plus our edits) and the source of truth; `setup.py` activates it. Workflow: change keys in Preferences > Keymap, run `bin/keymap-export`, commit `dcc.py` + `userpref.blend`. No per-hotkey Python. Export must run windowed: headless Blender never activates the preset, so it would export the default keymap. Convention on top of Industry Compatible: frequently used modeling ops sit on bare keys as modal operators in the `Mesh` keymap (D extrude, C bevel, S inset, Y merge, ...), pies on Alt/Shift+Q, and no animation keys in Object Mode. Operators the keymap calls that Blender lacks would live in `portable/scripts/startup/`, which Blender auto-loads (currently none).

## Conventions

- Scripts are deliberately tiny and comment-dense; keep that style. Explain *why* (e.g. the mirror choice, the zipball rename) in a trailing comment rather than adding structure.
- `portable/config/bookmarks.txt` is git-ignored: it holds machine-local recent paths, not config.
