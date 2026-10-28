#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for tool in rojo lune luau-compile luau-analyze python3; do command -v "$tool" >/dev/null; done
mapfile -t MIDNIGHT_SOURCES < <(find src tests -name '*.luau' -type f | sort)
luau-compile --null "${MIDNIGHT_SOURCES[@]}"
# These modules are engine-independent. Engine-wide type checking remains a Studio check.
luau-analyze src/server/Services/RoundModel.luau src/server/Services/EconomyService.luau
lune run tests/run.luau
lune run tests/world.luau
mkdir -p build
rojo build default.project.json -o build/MidnightDelivery.rbxlx
python3 tools/check_project.py
