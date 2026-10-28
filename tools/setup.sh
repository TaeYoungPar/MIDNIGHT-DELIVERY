#!/usr/bin/env bash
set -euo pipefail
# Linux x86_64 cloud tooling only; game runtime has no external dependencies.
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Use official Rojo/Lune releases for your OS.' >&2; exit 1; }
MIDNIGHT_TOOL_DIR="${MIDNIGHT_TOOL_DIR:-/workspace/tools-bin}"
mkdir -p "$MIDNIGHT_TOOL_DIR"
MIDNIGHT_DOWNLOAD_DIR="$(mktemp -d)"
trap 'rm -rf "$MIDNIGHT_DOWNLOAD_DIR"' EXIT
curl --fail --location --retry 2 --silent --show-error https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-linux-x86_64.zip -o "$MIDNIGHT_DOWNLOAD_DIR/rojo.zip"
curl --fail --location --retry 2 --silent --show-error https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip -o "$MIDNIGHT_DOWNLOAD_DIR/lune.zip"
curl --fail --location --retry 2 --silent --show-error https://github.com/luau-lang/luau/releases/download/0.744/luau-ubuntu.zip -o "$MIDNIGHT_DOWNLOAD_DIR/luau.zip"
python3 - "$MIDNIGHT_DOWNLOAD_DIR" "$MIDNIGHT_TOOL_DIR" <<'PY'
import pathlib,sys,zipfile
archives,destination=map(pathlib.Path,sys.argv[1:])
for archive,names in [('rojo',['rojo']),('lune',['lune']),('luau',['luau-compile','luau-analyze'])]:
    with zipfile.ZipFile(archives/(archive+'.zip')) as z:
        for name in names:
            target=destination/name
            target.write_bytes(z.read(name))
            target.chmod(0o755)
PY
"$MIDNIGHT_TOOL_DIR/rojo" --version
"$MIDNIGHT_TOOL_DIR/lune" --version
printf 'Tools installed. Add %s to PATH for this shell.\n' "$MIDNIGHT_TOOL_DIR"
