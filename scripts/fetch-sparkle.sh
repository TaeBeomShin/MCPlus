#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
VERSION=2.10.0
EXPECTED=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
ROOT="$PWD/.build/vendor"
ARCHIVE="$ROOT/Sparkle-$VERSION.tar.xz"
mkdir -p "$ROOT"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --proto '=https' --tlsv1.2 -L --fail --silent --show-error "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" -o "$ARCHIVE"
fi
ACTUAL="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || { print -u2 "Sparkle archive checksum mismatch"; exit 1; }
if [[ ! -d "$ROOT/Sparkle-$VERSION/Sparkle.framework" ]]; then
  mkdir -p "$ROOT/Sparkle-$VERSION"
  tar -xf "$ARCHIVE" -C "$ROOT/Sparkle-$VERSION"
fi
print "$ROOT/Sparkle-$VERSION"
