# dcc-blender

Portable Blender + my config, as one repo.

```sh
git clone <this repo> && cd dcc-blender && ./install.sh
bin/blender            # or open blender/Blender.app (also aliased to /Applications/Blender.app)
```

`install.sh` downloads the latest Blender into `blender/` (git-ignored), points its
portable config dir at `portable/`, and installs everything in `extensions.txt`.
Re-run it any time to upgrade.

Everything Blender saves lands in `portable/`, so it shows up in `git status`:

| In Blender | File |
| --- | --- |
| Preferences → Save Preferences | `portable/config/userpref.blend` |
| File → Defaults → Save Startup File | `portable/config/startup.blend` |
| Preferences → Keymap → "+" add preset | `portable/scripts/presets/keyconfig/<name>.py` |
| `bin/keymap-export` | `portable/scripts/presets/keyconfig/dcc.py` (user changes only, text diff) |

Extensions install into `portable/extensions/` (ignored); the source of truth is `extensions.txt`.
