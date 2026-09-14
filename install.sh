#!/bin/bash
# Install latest portable Blender into ./blender, link ./portable as its config dir, install plugins.
set -euo pipefail
cd "$(dirname "$0")"
REPO=$PWD
BASE=https://mirrors.dotsrc.org/blender/release   # download.blender.org sits behind a Cloudflare JS challenge; official mirror
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
  rm -rf blender && mkdir blender && ditto "$mnt/Blender.app" blender/Blender.app
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
    github)
      url=$(get "https://api.github.com/repos/$ref/releases/latest" | grep -oE '"browser_download_url": *"[^"]+\.zip"' | head -1 | cut -d'"' -f4 || true)
      tmp=$(mktemp -d); zip=$tmp/$(basename "$ref").zip
      get -o "$zip" "${url:-https://api.github.com/repos/$ref/zipball}"
      # zipballs unpack to owner-repo-sha/, not a valid module name; rename the top dir to the repo name
      [ -n "$url" ] || (cd "$tmp" && unzip -q "$zip" && rm "$zip" && mv "$(ls -d */)" "$(basename "$ref")" && zip -qr "$zip" "$(basename "$ref")")
      b --command extension install-file -r user_default --enable "$zip" ;;
    *) echo "unknown kind: $kind"; exit 1 ;;
  esac
done

# 5. Spotlight/Dock alias (only if absent or already ours)
[ ! -e /Applications/Blender.app ] || [ -L /Applications/Blender.app ] && ln -sfn "$REPO/blender/Blender.app" /Applications/Blender.app
echo "done: $(cat blender/VERSION)"
