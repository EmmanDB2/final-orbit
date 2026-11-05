# Learning log

Trail for `/teach` sessions: one entry per ticket. Teach sessions mark covered entries with "(covered)".

## 2026-11-05: Ticket 1, ship on screen, turns with keys

Files: `project.godot`, `scenes/main.tscn`, `scenes/ship.tscn`, `scripts/ship.gd`

- scenes and instancing
- delta time
- input actions

## 2026-11-05: Ticket 2, thrust and momentum

Files: `project.godot`, `scenes/ship.tscn`, `scripts/ship.gd`, `art/flame_main.png`

- velocity and momentum
- forward vector from sin and cos
- `_physics_process` and fixed time steps

## 2026-11-05: Ticket 3, camera follows the ship, starfield shader

Files: `scenes/main.tscn`, `scripts/starfield.gd`, `shaders/starfield.gdshader`, `data/starfield.tres`

- floating origin
- signals connected in a scene
- fragment shaders and uniforms

## 2026-11-05: Turn drift

Files: `scripts/ship.gd`, `docs/DESIGN.md`

- angular velocity and angular acceleration

## 2026-11-05: RAW and ASS flight modes

Files: `project.godot`, `scenes/main.tscn`, `scripts/ship.gd`, `scripts/assist_indicator.gd`, `art/hud_flight_mode.png`, `docs/DESIGN.md`

- `move_toward` for stopping exactly at a target
- signals that update the UI
- sprite sheets with `hframes`

## 2026-11-05: Ticket 4, first Android build on the Fold

Files: `export_presets.cfg`, `project.godot`, `.gitignore`, `docs/DESIGN.md`

- export presets and templates
- debug signing with a keystore
- Android `configChanges` and why folding doesn't restart the app
