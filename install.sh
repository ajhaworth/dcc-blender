#!/bin/bash
# Install latest portable Blender into ./blender, link ./portable as its config dir, install plugins.
set -euo pipefail
cd "$(dirname "$0")"
REPO=$PWD
BASE=https://ftp.nluug.nl/pub/graphics/blender/release   # download.blender.org sits behind a Cloudflare JS challenge and mirrors.dotsrc.org started 403ing listings (Sep 2026); official mirror
ARCH=$([ "$(uname -m)" = arm64 ] && echo arm64 || echo x64)
get() { curl -fsSL "$@"; }

# 1. resolve latest release
series=$(get $BASE/ | grep -oE 'Blender[0-9]+\.[0-9]+/' | sort -uV | tail -1)
dmg=$(get "$BASE/$series" | grep -oE "blender-[0-9.]+-macos-$ARCH\.dmg" | sort -uV | tail -1)
[ -n "$dmg" ] || { echo "no dmg found in $series"; exit 1; }

# 2. install if newer
if [ "$(cat blender/VERSION 2>/dev/null)" != "$dmg" ]; then
  echo "installing $dmg"
  tmp=$(mktemp -d); get -o "$tmp/b.dmg" "$BASE/$series$dmg"
  mnt=$(hdiutil attach -nobrowse -readonly "$tmp/b.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
  mkdir -p blender; rm -rf blender/Blender.app   # only the bundle: rm -rf of the dir races Finder's .DS_Store and fails
  ditto "$mnt/Blender.app" blender/Blender.app   # one statement per line so set -e aborts before VERSION is written
  hdiutil detach "$mnt" -quiet; rm -rf "$tmp"
  echo "$dmg" > blender/VERSION
fi

# 3. portable config dir -> repo
ln -sfn "$REPO/portable" blender/Blender.app/Contents/Resources/portable
b() { blender/Blender.app/Contents/MacOS/Blender --online-mode "$@"; }

# 4. plugins
{ grep -vE '^\s*(#|$)' extensions.txt || true; } | while read -r kind ref; do
  case $kind in
    blender_org) b --command extension install "$ref" --sync --enable ;;
    github|forgejo)   # forgejo (e.g. projects.blender.org) serves the same releases API under /api/v1
      api=$([ "$kind" = github ] && echo "https://api.github.com/repos/$ref" || echo "https://${ref%%/*}/api/v1/repos/${ref#*/}")
      url=$(get "$api/releases/latest" | grep -oE '"browser_download_url": *"[^"]+\.zip"' | head -1 | cut -d'"' -f4 || true)
      tmp=$(mktemp -d); zip=$tmp/$(basename "$ref").zip
      get -o "$zip" "${url:-$api/zipball}"
      # zipballs unpack to owner-repo-sha/, not a valid module name; rename the top dir to the repo name
      [ -n "$url" ] || (cd "$tmp" && unzip -q "$zip" && rm "$zip" && mv "$(ls -d */)" "$(basename "$ref")" && zip -qr "$zip" "$(basename "$ref")")
      b --command extension install-file -r user_default --enable "$zip" ;;
    *) echo "unknown kind: $kind"; exit 1 ;;
  esac
done

# 5. Spotlight/Dock alias (only if absent or already ours)
[ ! -e /Applications/Blender.app ] || [ -L /Applications/Blender.app ] && ln -sfn "$REPO/blender/Blender.app" /Applications/Blender.app

# 6. Blender Lab MCP server for Claude Code (add-on comes from extensions.txt). Not vendored: uvx runs it
#    straight from upstream git, and --refresh-package re-pulls main on every launch so it's always latest.
if command -v claude >/dev/null && command -v uvx >/dev/null; then
  claude mcp remove -s user blender >/dev/null 2>&1 || true
  claude mcp add -s user blender -- uvx --refresh-package blender-mcp \
    --from 'git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp' blender-mcp
else echo "skip MCP registration: need claude + uvx"; fi
echo "done: $(cat blender/VERSION)"
