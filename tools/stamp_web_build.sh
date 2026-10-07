#!/usr/bin/env bash
# Gives a web export's files release-unique names so browsers can't mix a new
# page with old cached game files. index.html keeps its name (it's the entry
# point and is only cached briefly); everything it loads is renamed from
# index.* to game-<version>.*.
#   tools/stamp_web_build.sh build/web <version>
set -euo pipefail
dir="$1"
version="$2"
base="game-${version}"
cd "$dir"
for f in index.*; do
	[ "$f" = "index.html" ] && continue
	mv "$f" "${base}${f#index}"
done
sed -i \
	-e "s/\"executable\":\"index\"/\"executable\":\"${base}\"/" \
	-e "s/\"index\.\(pck\|wasm\)\"/\"${base}.\1\"/g" \
	-e "s/\(src\|href\)=\"index\.\([a-z.-]*\)\"/\1=\"${base}.\2\"/g" \
	index.html
if grep -q '"index\.\|="index\.' index.html; then
	echo "index.html still references unstamped files" >&2
	exit 1
fi
