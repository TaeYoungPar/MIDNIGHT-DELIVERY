#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for tool in rojo lune luau-compile luau-analyze python3; do command -v "$tool" >/dev/null; done
mapfile -t MIDNIGHT_SOURCES < <(find src tests -name '*.luau' -type f | sort)
luau-compile --null "${MIDNIGHT_SOURCES[@]}"
# These modules are engine-independent. Engine-wide type checking remains a Studio check.
luau-analyze src/server/Services/RoundModel.luau src/server/Services/EconomyService.luau src/server/Services/OrderModel.luau src/server/Services/OrderPlanner.luau src/shared/OrderCatalog.luau src/server/Services/PlayerStateModel.luau src/server/Services/MovementModel.luau src/server/Services/ActionLimiter.luau src/server/Services/ProfileModel.luau
lune run tests/run.luau
lune run tests/orders.luau
lune run tests/recovery.luau
lune run tests/monsters.luau
lune run tests/vehicles.luau
lune run tests/vehicle_client.luau
lune run tests/profiles.luau
lune run tests/data_service.luau
lune run tests/audio.luau
lune run tests/settings_ui.luau
lune run tests/hud.luau
lune run tests/round_integration.luau
lune run tests/world.luau
mkdir -p build
rojo build default.project.json -o build/MidnightDelivery.rbxlx
python3 tools/check_project.py
