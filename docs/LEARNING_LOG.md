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

## 2026-11-05: Star tint prototype

Files: `scripts/feature_flags.gd`, `scripts/star_data.gd`, `scripts/star_light.gd`, `scripts/starfield.gd`, `shaders/starfield.gdshader`, `data/test_star.tres`, `data/starfield.tres`, `scenes/main.tscn`, `docs/DESIGN.md`

- custom `Resource` classes for data
- feature flags with `class_name` constants
- inverse-square light falloff

## 2026-11-05: Ticket 5, part 1: physics core (GDExtension, GravityModel, PatchedConicsModel)

Files: `native/SConstruct`, `native/src/*`, `bin/final_orbit.gdextension`, `tests/test_gravity_model.gd`, `export_presets.cfg`, `.gitignore`, `.gitmodules`

- GDExtension: C++ classes that GDScript can call
- abstract interfaces and virtual methods
- what a closed-form orbit is, used rather than derived

## 2026-11-05: Ticket 5, part 2: planet, zoom tiers, and first orbit

Files: `project.godot`, `scenes/main.tscn`, `scenes/ship.tscn`, `scripts/main.gd`, `scripts/ship.gd`, `scripts/flight_view.gd`, `scripts/planet_view.gd`, `scripts/body_data.gd`, `scripts/starfield.gd`, `shaders/planet.gdshader`, `data/home_planet.tres`, `data/test_star.tres`, `art/ship_icon.png`, `docs/DESIGN.md`

- thrust as small velocity changes on top of an exact orbit
- drawing a planet with a shader instead of a sprite
- one script that sets up the others and hands them what they need

## 2026-11-05: Ticket 6, trajectory preview

Files: `scripts/trajectory_preview.gd`, `scripts/ship.gd`, `scripts/main.gd`, `scenes/main.tscn`, `native/src/patched_conics_model.cpp`, `native/src/patched_conics_model.h`, `native/src/gravity_model.h`, `tests/test_gravity_model.gd`, `docs/DESIGN.md`

- caching: only redoing work when something has changed
- custom drawing with `_draw` and `queue_redraw`
- moving a node instead of recalculating what it draws

## 2026-11-05: Rough touch controls

Files: `scripts/rough_touch_controls.gd`, `scenes/main.tscn`, `docs/DESIGN.md`

- multi-touch: tracking fingers by index
- pressing input actions from code, with analog strength
- `_input` compared with `_physics_process`

## 2026-11-05: Ticket 7, moon on rails and sphere of influence

Files: `native/src/patched_conics_model.cpp`, `native/src/patched_conics_model.h`, `native/src/gravity_model.cpp`, `native/src/gravity_model.h`, `tests/test_gravity_model.gd`, `scripts/body_view.gd`, `scripts/body_guides.gd`, `scripts/body_data.gd`, `scripts/flight_view.gd`, `scripts/main.gd`, `scripts/trajectory_preview.gd`, `scenes/main.tscn`, `data/moon.tres`, `docs/DESIGN.md`

- what a sphere of influence is and why the frame switches there
- computing a moon's position from time instead of simulating it
- reusing one shader and script for several bodies

## 2026-11-05: Ticket 10, landing and the landing line

Files: `native/src/patched_conics_model.cpp`, `native/src/patched_conics_model.h`, `native/src/gravity_model.cpp`, `native/src/gravity_model.h`, `native/src/ship_state.cpp`, `native/src/ship_state.h`, `tests/test_gravity_model.gd`, `scripts/ship.gd`, `scripts/telemetry_readout.gd`, `scripts/trajectory_preview.gd`, `scripts/flight_view.gd`, `scripts/body_data.gd`, `scripts/main.gd`, `scenes/main.tscn`, `shaders/planet.gdshader`, `data/home_planet.tres`, `data/moon.tres`, `art/hud_font.png`, `docs/DESIGN.md`

- speed relative to the ground versus speed relative to space
- drawing text from a sprite sheet with `draw_texture_rect_region`
- splitting a line where it crosses a threshold, with `lerp`

## 2026-11-05: Ticket 9, fitting any screen

Files: `scripts/screen_fit.gd`, `scripts/safe_area.gd`, `scripts/flight_view.gd`, `scripts/rough_touch_controls.gd`, `scripts/telemetry_readout.gd`, `scenes/main.tscn`, `docs/DESIGN.md`

- stretch settings and whole-number pixel scaling
- anchors and safe areas for reactive UI
- when a signal doesn't fire, and checking the value yourself

## 2026-11-05: Ticket 8, the real flight UI

Files: `scripts/ui/*`, `data/agency_palette.tres`, `scripts/ship.gd`, `scripts/flight_view.gd`, `scripts/telemetry_readout.gd`, `scripts/main.gd`, `scenes/main.tscn`, `project.godot`, `native/src/*`, `tests/test_gravity_model.gd`, `docs/DESIGN.md`

- custom-drawn `Control` nodes and `_draw`
- routing several fingers to different widgets
- steering to a heading with a bang-bang control law

## 2026-11-05: Tier 1, ticket 1: ships as data, with mass from pixels

Files: `scripts/ship/*`, `data/materials/*`, `data/lander_design.tres`, `scripts/ship.gd`, `scenes/ship.tscn`, `tests/test_ship_body.gd`, `docs/DESIGN.md`, `CLAUDE.md`

- custom resources that hold other resources
- center of mass and moment of inertia
- reading an image's pixels with `Image.get_pixel`

## 2026-11-05: Tier 1, ticket 2: fuel

Files: `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/ship/module_data.gd`, `scripts/ui/plate_panel.gd`, `scripts/ui/top_bar.gd`, `scripts/ui/flight_hud.gd`, `data/lander_design.tres`, `tests/test_ship_body.gd`, `docs/DESIGN.md`

- the rocket equation and delta-v
- exhaust velocity and burn rate
- why a ship gets quicker as it empties

## 2026-11-05: Tier 1, ticket 3: RCS pad and translation

Files: `scripts/ui/rcs_button.gd`, `scripts/ui/flight_hud.gd`, `scripts/ui/ui_button.gd`, `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `data/lander_design.tres`, `project.godot`, `docs/DESIGN.md`

- directions relative to the ship: forward and right vectors from the heading
- buttons that hold an input action down
- one layout function serving two screens

## 2026-11-05: Tier 1, ticket 4: RCS puffs

Files: `scripts/rcs_puffs.gd`, `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `scenes/ship.tscn`, `data/lander_design.tres`, `docs/DESIGN.md`

- why a thruster above the center of mass turns the ship
- child nodes that follow their parent's rotation

## 2026-11-05: Ship sprite has no minimum size

Files: `scripts/ship.gd`, `docs/DESIGN.md`

- scaling a sprite with the zoom

## 2026-11-05: Tier 1, ticket 5: the real star and nested rails

Files: `native/src/patched_conics_model.*`, `native/src/gravity_model.*`, `tests/test_gravity_model.gd`, `scripts/main.gd`, `scripts/flight_view.gd`, `scripts/trajectory_preview.gd`, `scripts/body_guides.gd`, `scripts/body_view.gd`, `scripts/star_view.gd`, `scripts/star_light.gd`, `scripts/star_data.gd`, `scripts/starfield.gd`, `scripts/ship.gd`, `shaders/star.gdshader`, `scenes/main.tscn`, `data/home_star.tres`, `data/home_planet.tres`, `docs/DESIGN.md`

- nested reference frames
- spheres of influence inside spheres of influence
- 32-bit screen coordinates and floating origins

## 2026-11-05: Tier 1, ticket 6: spinning planets

Files: `native/src/patched_conics_model.*`, `native/src/gravity_model.h`, `tests/test_gravity_model.gd`, `scripts/main.gd`, `scripts/body_data.gd`, `scripts/body_view.gd`, `shaders/planet.gdshader`, `data/home_planet.tres`, `data/moon.tres`, `docs/DESIGN.md`

- rotating a coordinate in a shader
- velocity of a point on a turning body

## 2026-11-05: Tier 1, ticket 7: atmospheres

Files: `native/src/patched_conics_model.*`, `native/src/gravity_model.*`, `tests/test_gravity_model.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/body_data.gd`, `scripts/body_view.gd`, `scripts/main.gd`, `shaders/planet.gdshader`, `data/home_planet.tres`, `docs/DESIGN.md`

- the drag equation
- exponential thinning of air with height

## 2026-11-05: Tier 1, ticket 8: re-entry heat

Files: `scripts/reentry_glow.gd`, `scripts/ship.gd`, `scripts/rcs_puffs.gd`, `scripts/ui/agency_palette.gd`, `data/agency_palette.tres`, `scenes/ship.tscn`, `docs/DESIGN.md`

- why heating grows with the cube of speed
- static functions shared between scripts

## 2026-11-05: Double the lander's fuel

Files: `data/lander_design.tres`, `docs/DESIGN.md`

- the rocket equation and why more fuel means a heavier ship

## 2026-11-05: Tier 1, ticket 9: live ship pixels

Files: `scripts/ship/ship_body.gd`, `scripts/ship/material_data.gd`, `scripts/ship/ship_design.gd`, `data/materials/*`, `tests/test_ship_body.gd`

- flood fill for connected pieces
- counting sort
- convex hulls for finding what touches first

## 2026-11-05: Tier 1, ticket 10: damage

Files: `scripts/ship.gd`, `scripts/debris_field.gd`, `scripts/telemetry_readout.gd`, `scripts/rcs_puffs.gd`, `scripts/star_light.gd`, `scripts/star_data.gd`, `scripts/main.gd`, `scripts/ui/flight_hud.gd`, `scenes/main.tscn`, `data/home_star.tres`, `data/lander_design.tres`, `docs/DESIGN.md`

- kinetic energy and reduced mass in a collision
- torque from off-center forces
- updating a texture at runtime

## 2026-11-06: Heading dial steady when landed

Files: `scripts/ship.gd`, `scripts/ui/heading_dial.gd`, `docs/DESIGN.md`

- atan2 and floating-point noise near zero

## 2026-11-06: Damage polish

Files: `scripts/ship/damage_wave.gd`, `scripts/spark_field.gd`, `scripts/debris_field.gd`, `scripts/ship.gd`, `scripts/main.gd`, `scenes/main.tscn`, `docs/DESIGN.md`

- separating what's simulated from what's drawn
- inner classes and parallel arrays for many small things
- process priority for keeping systems in step

## 2026-11-06: Tier 1, ticket 11: ships from module PNGs

Files: `tools/slice_lander.gd`, `art/lander/*`, `data/lander_design.tres`, `scripts/ship/ship_body.gd`, `scripts/ship/module_data.gd`, `scripts/ship/ship_design.gd`, `scripts/ship/damage_wave.gd`, `scripts/ship.gd`, `scripts/rcs_puffs.gd`, `tests/test_ship_body.gd`, `docs/DESIGN.md`

- composing a picture from smaller images
- inner classes for grouping related data
- a tool script that only runs from the command line

## 2026-11-06: Tier 1, ticket 12: landing legs

Files: `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/telemetry_readout.gd`, `scripts/ui/flight_hud.gd`, `project.godot`, `docs/DESIGN.md`

- flipping a sprite with a negative scale
- balance: a center of mass over a support edge
- input actions shared between keys and buttons

## 2026-11-06: Tier 1, ticket 13: inside layers

Files: `art/ship_lander_frame.png`, `art/ship_lander_systems.png`, `art/lander/*`, `tools/slice_lander.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/module_data.gd`, `scripts/ship/ship_design.gd`, `scripts/ship/damage_wave.gd`, `data/lander_design.tres`, `data/materials/*`, `tests/test_ship_body.gd`, `docs/DESIGN.md`

- one array holding several values per pixel
- several sorted fronts walking through one list

## 2026-11-06: Drop loose pixels

Files: `scripts/ship/ship_body.gd`, `scripts/ship/damage_wave.gd`, `scripts/ship.gd`, `scripts/debris_field.gd`, `tests/test_ship_body.gd`, `docs/DESIGN.md`

- union-find for connected pieces
- runs of pixels instead of single pixels

## 2026-11-06: Planet look

Files: `shaders/planet.gdshader`, `scripts/body_view.gd`, `scripts/body_data.gd`, `scripts/main.gd`, `data/home_planet.tres`, `data/moon.tres`, `docs/DESIGN.md`

- domain warping noise
- lighting a disc as if it were a ball
- ordered dithering with screen-space derivatives

## 2026-11-06: Pixel-art planets from far out

Files: `shaders/planet.gdshader`, `scripts/body_view.gd`, `docs/DESIGN.md`

- limiting a palette so art reads as pixels
- snapping a shader's pixels to bigger blocks

## 2026-11-06: Terrain ticket 1: pixel snapping

Files: `shaders/planet.gdshader`, `scripts/body_view.gd`

- polar coordinates for a rim
- keeping shader numbers small by measuring from the view

## 2026-11-06: Terrain ticket 2: terrain silhouette

Files: `native/src/terrain_profile.*`, `native/src/patched_conics_model.*`, `native/src/gravity_model.*`, `tests/test_gravity_model.gd`, `shaders/planet.gdshader`, `scripts/body_view.gd`, `scripts/body_data.gd`, `scripts/main.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `data/home_planet.tres`, `data/moon.tres`

- 1D noise that loops around a circle
- sending data to a shader through a texture
- one source of numbers for physics and drawing

## 2026-11-06: Terrain ticket 3: detail by zoom

Files: `shaders/planet.gdshader`

- level of detail
- noise octaves as tiers of features

## 2026-11-06: Terrain ticket 4: cross-section view

Files: `shaders/planet.gdshader`, `scripts/body_data.gd`, `scripts/body_view.gd`, `data/home_planet.tres`, `data/moon.tres`

- layering colors by depth
- growing one look over another as zoom changes

## 2026-11-06: Terrain ticket 5: sky

Files: `shaders/planet.gdshader`, `scripts/body_data.gd`, `scripts/body_view.gd`, `data/home_planet.tres`

- ordered dithering for bands of color
- alpha blending over a background

## 2026-11-06: Terrain ticket 6: surface props

Files: `scripts/surface_props.gd`, `scripts/body_data.gd`, `scripts/main.gd`, `scenes/main.tscn`, `data/home_planet.tres`, `data/moon.tres`

- placing things from a seed so they're always the same
- caching what's expensive to work out

## 2026-11-06: Terrain ticket 7: juice

Files: `scripts/ground_effects.gd`, `scripts/spark_field.gd`, `scripts/ship.gd`, `scripts/body_view.gd`, `scripts/body_data.gd`, `scripts/main.gd`, `shaders/planet.gdshader`, `native/src/terrain_profile.*`, `native/src/patched_conics_model.*`, `native/src/gravity_model.*`, `scenes/main.tscn`, `tests/test_gravity_model.gd`

- parallax by moving through noise slower
- process priority to keep systems at the same moment
- raycasting down to the ground

## 2026-11-06: Re-entry rebuilt

Files: `shaders/reentry.gdshader`, `scripts/reentry_glow.gd`, `scripts/ship.gd`, `scripts/ui/agency_palette.gd`, `data/agency_palette.tres`, `scenes/ship.tscn`, `docs/DESIGN.md`

- using a texture as a mask in a shader
- marching along a direction in a shader
- inner classes that extend a node

## 2026-11-06: Procedural burn animation

Files: `shaders/engine_flame.gdshader`, `scripts/engine_flame.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scenes/ship.tscn`, `tests/test_ship_body.gd`, `docs/DESIGN.md`

- shaping an effect from game state with uniforms
- easing a value toward a target over time

## 2026-11-06: Cut the station art into sprites

Files: `tools/slice_station.gd`, `art/station_1/`, `scripts/ui/agency_palette.gd`, `data/agency_palette.tres`, `docs/DESIGN.md`

- flood fill and connected pieces
- matching colors in a perceptual color space (Oklab)
- keeping files out of a Godot project with `.gdignore`

## 2026-11-06: Home Station in orbit

Files: `native/src/gravity_model.*`, `native/src/patched_conics_model.*`, `scripts/station/`, `data/station_1.tres`, `scripts/main.gd`, `scripts/body_guides.gd`, `scenes/main.tscn`, `tests/test_gravity_model.gd`, `tests/test_station.gd`, `docs/DESIGN.md`

- Kepler rails computed from the time
- nested resources in a data file
- turning pixel art in quarter turns

## 2026-11-06: Edge marker for the station

Files: `scripts/ui/target_markers.gd`, `scripts/ui/flight_hud.gd`, `scripts/ui/ui_style.gd`, `scripts/main.gd`, `scenes/main.tscn`, `docs/DESIGN.md`

- clipping a line to a rectangle
- a signal carrying layout from one UI system to another

## 2026-11-06: The station is solid

Files: `scripts/station/station_view.gd`, `scripts/station/station_layout.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- collision against a pixel mask
- a contact impulse with spin
- physics priority to order systems within a tick

## 2026-11-06: Docking

Files: `scripts/station/station_view.gd`, `scripts/station/station_design.gd`, `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `data/lander_design.tres`, `scripts/ui/flight_hud.gd`, `scripts/ui/top_bar.gd`, `scripts/telemetry_readout.gd`, `scenes/main.tscn`, `project.godot`, `docs/DESIGN.md`

- moving between world and rotating frames
- velocity of a point on something turning
- handing a Callable to another system

## 2026-11-06: The camera turns so down is down

Files: `scripts/flight_view.gd`, `shaders/planet.gdshader`, `shaders/starfield.gdshader`, `scripts/body_view.gd`, `scripts/star_view.gd`, `scripts/starfield.gd`, `scripts/body_guides.gd`, `scripts/station/station_view.gd`, `scripts/ui/turn_guide.gd`, `scripts/ui/heading_dial.gd`, `scripts/ui/target_markers.gd`, `scenes/main.tscn`, `docs/DESIGN.md`

- Camera2D rotation and the canvas transform
- rotating screen-space shader samples
- CanvasLayers ignoring the camera

## 2026-11-06: Tap anything to focus the zoom

Files: `scripts/flight_view.gd`, `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- telling a tap from a drag and a hold
- turning a screen position back into a world position
- a Dictionary as a small tagged value

## 2026-11-06: Flight UI rework and context cards

Files: `tools/make_hud_font.gd`, `art/hud_font.png`, `scripts/ui/`, `scripts/world_catalog.gd`, `scripts/flight_view.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/station/station_design.gd`, `scripts/body_data.gd`, `scripts/star_data.gd`, `scripts/main.gd`, `data/`, `scenes/main.tscn`, `docs/DESIGN.md`

- telling a tap, a hold, and a drag apart
- pausing the tree while one branch keeps running
- bitmap fonts drawn from a texture atlas

## 2026-11-06: EVA and station boarding

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `data/pilot.tres`, `scripts/station/station_view.gd`, `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `data/lander_design.tres`, `scripts/flight_view.gd`, `scripts/ui/flight_hud.gd`, `scripts/ui/target_markers.gd`, `scripts/ui/comms_line.gd`, `scripts/world_catalog.gd`, `scripts/feature_flags.gd`, `scripts/main.gd`, `scenes/main.tscn`, `project.godot`, `docs/DESIGN.md`

- a small state machine for who the player is
- keeping two objects on the same physics clock
- sliding along walls by moving one axis at a time

## 2026-11-06: App icon

Files: `art/final_orbit_icon.png`, `art/icon/`, `tools/make_icons.gd`, `project.godot`, `export_presets.cfg`

- Android adaptive icon layers and their safe zone

## 2026-11-06: Different colors for orbits and gravity

Files: `scripts/body_guides.gd`, `docs/DESIGN.md`

- exported colors as data on a node

## 2026-11-06: Rotate buttons in the D-pad corners

Files: `scripts/ui/flight_hud.gd`, `scripts/ui/rcs_button.gd`, `docs/DESIGN.md`

- removing a mode by giving each action its own button

## 2026-11-06: Animated astronaut

Files: `art/pilot/`, `tools/slice_pilot.gd`, `scripts/pilot.gd`, `scripts/pilot_data.gd`, `data/pilot.tres`, `docs/DESIGN.md`

- sprite sheets with hframes and vframes
- mirroring a sprite to save drawing frames
- picking a frame from a state and a timer

## 2026-11-09: Side-view pilot sheet cut

Files: `tools/slice_pilot_side.gd`, `art/pilot/pilot_side.png`, `art/pilot/source/pilot_side_sheet.png`

- finding a pixel grid's phase from where the edges line up
- matching colors in a perceptual color space (Oklab)
- aligning animation frames on an anchor point

## 2026-11-09: Walking on worlds

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `data/pilot.tres`, `scripts/feature_flags.gd`, `scripts/ship.gd`, `scripts/ui/flight_hud.gd`, `scripts/world_catalog.gd`, `docs/DESIGN.md`

- polar coordinates on a spinning body
- 64-bit floats versus 32-bit Vector2
- projectile motion (v²/2g, 2v/g) and edge-triggered input

## 2026-11-09: 3D pilot model

Files: `scripts/pilot/astronaut_model.gd`, `tests/test_astronaut_model.gd`, `docs/DESIGN.md`

- a tree of Node3D joints, each placed relative to its parent
- building meshes in code (BoxMesh, SphereMesh, an ArrayMesh from vertex arrays)
- triangle winding order, and which side of a face shows

## 2026-11-09: 3D pilot drawn as pixel art

Files: `scripts/pilot/astronaut_view.gd`, `scripts/pilot/astronaut_pixels.gdshader`, `scripts/pilot/astronaut_depth.gdshader`, `scripts/pilot.gd`, `scripts/feature_flags.gd`, `scripts/station/station_view.gd`, `docs/DESIGN.md`

- rendering 3D into a 2D texture with a SubViewport and an orthographic camera
- a post-process shader: snapping colors to a palette and finding edges from depth
- procedural animation: posing joints from sine waves and game state

## 2026-11-09: EVA steers like the ship, with RCS puffs

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- angular velocity and braking to stop on a heading
- pushing in a body's own frame, then rotating into the world
- torque from a pair of thrusters on opposite corners

## 2026-11-10: EVA pilot leans into pushes

Files: `scripts/pilot/astronaut_view.gd`, `scripts/pilot.gd`, `docs/DESIGN.md`

- building a rotation from an axis and an angle (Basis)
- easing a vector toward a target with move_toward
- choosing points by sorting with a custom comparison

## 2026-11-10: Real units from the pilot's height

Files: `scripts/units.gd`, `scripts/ui/top_bar.gd`, `scripts/world_catalog.gd`, `scripts/ui/target_markers.gd`, `scripts/ui/ui_style.gd`, `docs/DESIGN.md`

- unit conversion kept in one place (a static helper class)
- how quantities scale with length: distance, speed, and mass from mu (length cubed)
- formatting numbers for display (decimals, thousands separators)

## 2026-11-10: Launch base art cut into sprites

Files: `tools/slice_launch_base.gd`, `art/launch_base/`, `docs/DESIGN.md`

- downsampling by voting (the mode) instead of averaging, to keep crisp colors
- connected components, to keep the building and drop specks
- scaling art by a known size (a door) when there's no pixel grid

## 2026-11-10: Launch base placed on the home planet

Files: `native/src/terrain_profile.h`, `native/src/terrain_profile.cpp`, `native/src/patched_conics_model.h`, `native/src/patched_conics_model.cpp`, `scripts/site/site_data.gd`, `scripts/site/site_building.gd`, `scripts/site/site_view.gd`, `data/launch_base.tres`, `scripts/main.gd`, `scripts/flight_view.gd`, `scripts/world_catalog.gd`, `scripts/surface_props.gd`, `tests/test_gravity_model.gd`, `docs/DESIGN.md`

- blending two values with smoothstep
- placing things on a spinning body with polar coordinates
- custom Resource classes nested inside a .tres file

## 2026-11-10: Launch base buildings are solid to ships

Files: `scripts/site/site_view.gd`, `scripts/site/site_building.gd`, `data/launch_base.tres`, `scripts/ship.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- collision against an image's alpha in a turned frame
- a surface normal from the empty space around a point
- impulse with a lever arm: why an off-center hit spins as well as slows

## 2026-11-10: Walking into the launch base

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/site/site_view.gd`, `scripts/site/site_building.gd`, `data/launch_base.tres`, `scripts/ui/flight_hud.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- a state machine with a new state (indoors), and its ways in and out
- local coordinates on a picture, turned into world coordinates
- fading with alpha (modulate) toward a target over time

## 2026-11-10: Cleaned-up launch base art

Files: `art/launch_base/*.png`, `data/launch_base.tres`, `docs/DESIGN.md`, removed `tools/slice_launch_base.gd`

- art coordinates kept in data, so new art means new numbers, not new code
- a sprite's transparent margin and where its ground line sits (sink)
- Godot reimporting a changed texture

## 2026-11-10: Moon base

Files: `art/moon_base/*.png`, `tools/split_moon_pad.gd`, `data/moon_base.tres`, `scripts/main.gd`, `scripts/site/site_building.gd`, `scripts/site/site_view.gd`, `scripts/world_catalog.gd`, `docs/DESIGN.md`

- reusing a system with new data: a second site on another world, no new site code
- a tool script that cuts an image into regions (get_region, fill_rect) without resizing
- filtering an array with a lambda (Array.filter)

## 2026-11-10: Landed ships kept out of buildings

Files: `scripts/ship.gd`, `docs/DESIGN.md`

- projecting a vector onto a plane (removing its "up" part) to move along the ground
- resolving overlap a little each tick instead of all at once

## 2026-11-10: RCS propellant tank

Files: `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `scripts/world_catalog.gd`, `docs/DESIGN.md`

- a second resource with its own drain and refill
- the rocket equation with mass that the engine doesn't burn (dry mass plus RCS propellant)

## 2026-11-10: ENGINE switch

Files: `scripts/ship.gd`, `scripts/ui/engine_button.gd` (was `burn_button.gd`), `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- a toggle on "just pressed" versus an action held down
- a property setter that redraws (engine_on)
- safety cutoffs: one function every event calls

## 2026-11-10: HUD rearranged to the mockup

Files: `scripts/ui/flight_hud.gd`, `scripts/ui/top_bar.gd`, `scripts/ui/heading_dial.gd`, `scripts/ui/throttle_lever.gd`, `scripts/ui/tank_gauges.gd`, `scripts/ui/side_panel.gd`, `scripts/ui/side_tab.gd`, `docs/DESIGN.md`

- laying out controls from the screen's corners so it fits any width
- custom drawing with _draw (arcs, polygons, ticks around a circle)
- a tap versus a drag on the same widget

## 2026-11-10: Time warp

Files: `scripts/time_warp.gd`, `scripts/ui/warp_control.gd`, `scripts/ui/flight_hud.gd`, `scripts/main.gd`, `scripts/ship.gd`, `scripts/flight_view.gd`, `scripts/ui/comms_line.gd`, `scripts/ui/engine_button.gd`, `scripts/ui/turn_guide.gd`, `scripts/station/station_view.gd`, `scripts/site/site_view.gd`, `project.godot`, `docs/DESIGN.md`

- Engine.time_scale, and sim time versus real time
- static functions on a class (TimeWarp.real, TimeWarp.on_rails)
- input actions added in project.godot

## 2026-11-10: Aerodynamics

Files: `native/src/aero_body.h`, `native/src/aero_body.cpp`, `native/src/register_types.cpp`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/ship/ship_design.gd`, `scripts/feature_flags.gd`, `tests/test_aerodynamics.gd`, `docs/DESIGN.md`

- force and torque summed over the pieces of an outline (center of pressure against center of mass)
- substeps and an energy check to keep a simulation steady at long time steps
- driving a scene's physics tick by hand from a test

## 2026-11-10: Landing prediction

Files: `native/src/gravity_model.h`, `native/src/gravity_model.cpp`, `native/src/aero_body.h`, `native/src/aero_body.cpp`, `native/src/patched_conics_model.h`, `native/src/patched_conics_model.cpp`, `scripts/landing_prediction.gd`, `scripts/landing_path.gd`, `scripts/ui/landing_label.gd`, `scripts/trajectory_preview.gd`, `scripts/ship.gd`, `scripts/ui/comms_line.gd`, `scripts/main.gd`, `tests/test_landing_prediction.gd`, `docs/DESIGN.md`

- worker threads: starting a task, checking whether it's done, and never waiting on it (WorkerThreadPool)
- handing a thread its own copies, so nothing changes under it
- a rotating frame of reference: drawing a path against ground that turns

## 2026-11-10: STAB against the turning ground

Files: `native/src/gravity_model.{h,cpp}`, `docs/DESIGN.md`

- frames of reference: velocity measured against the body versus against its turning ground
- one shared function for the real flight and the forecast, so they can't drift apart
- guarding a direction that's undefined when the speed is near zero

## 2026-11-10: In-world context menus

Files: `scripts/ui/context_menu.gd`, `scripts/ui/flight_hud.gd`, `scripts/pilot.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/station/station_view.gd`, `scripts/site/site_view.gd`, `scripts/flight_view.gd`, `docs/DESIGN.md`

- world coordinates to screen coordinates (camera center, zoom, and roll)
- storing a Callable (a lambda) to work something out later, each frame
- one clock for everything that moves, so positions agree

## 2026-11-10: Context menus that move out of the way

Files: `scripts/ui/context_menu.gd`, `scripts/ui/flight_hud.gd`, `scripts/pilot.gd`, `scripts/ship.gd`, `docs/DESIGN.md`

- scoring candidate positions and picking the cheapest (overlap areas as cost)
- hysteresis: only switching when the new choice is clearly better
- easing toward a target each frame with an exponential (frame-rate independent)

## 2026-11-10: Gigs, ticket 1: data, boards, credits, and cargo mass

Files: `scripts/gig/gig_type.gd`, `scripts/gig/gig.gd`, `scripts/gig/agency.gd`, `data/gigs/cargo.tres`, `scripts/ship.gd`, `scripts/ship/ship_design.gd`, `scripts/world_catalog.gd`, `scripts/main.gd`, `scripts/ui/ui_style.gd`, `tools/make_hud_font.gd`, `art/hud_font.png`, `data/station_1.tres` (name only), `docs/DESIGN.md`

- seeded random numbers: the same seed and inputs give the same results
- Resources as data (GigType) versus plain objects (Gig, RefCounted)
- the rocket equation with cargo as dry mass

## 2026-11-10: Gigs, ticket 2: the gig board screen

Files: `scripts/ui/gig_board.gd`, `scripts/ui/flight_hud.gd`, `scripts/ui/comms_line.gd`, `scripts/pilot.gd`, `scripts/site/site_building.gd`, `data/launch_base.tres`, `data/moon_base.tres`, `scripts/main.gd`, `tools/make_hud_font.gd`, `art/hud_font.png`, `scripts/ui/ui_style.gd`, `docs/DESIGN.md`

- a modal screen: one widget that takes every touch while it's up
- hit-testing named regions (rows, buttons) from one finger position
- word wrapping text to a width

## 2026-11-10: Gigs, ticket 3: delivering cargo

Files: `scripts/ui/flight_hud.gd`, `docs/DESIGN.md` (with the agency's delivery from ticket 1)

- merging choices from two sources into one menu, each row keeping its own action (Callables)
- an event bus in practice: the agency adds menu rows without the station or sites knowing

## 2026-11-10: Gigs, ticket 4: the active-gig tracker

Files: `scripts/ui/gig_tracker.gd`, `scripts/ui/flight_hud.gd`, `scripts/gig/agency.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- one widget with two looks (open panel, folded tab) and a state flag
- reacting to a signal (gig_changed) to set the target marker once per gig
- touch priority: which widget gets a finger when two overlap

## 2026-11-10: Gigs, ticket 5: survey gigs

Files: `scripts/gig/agency.gd`, `scripts/gig/gig.gd`, `scripts/gig/gig_type.gd`, `data/gigs/survey.tres`, `scripts/ui/survey_marker.gd`, `scripts/ui/gig_board.gd`, `scripts/ui/flight_hud.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- line of sight: the closest point on a segment to a circle's center
- angles around a turning world (a spot's angle grows with the world's spin)
- progress over time that pauses when its condition breaks

## 2026-11-10: Gig fixes: opening tap, tracker, rows, auto-hide off

Files: `scripts/ui/gig_board.gd`, `scripts/ui/gig_tracker.gd`, `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- one input event seen by two systems in the same frame, and arming a screen until keys are let go
- keeping a list's look consistent by deciding the layout once for all rows

## 2026-11-10: Context menus shrink zoomed out

Files: `scripts/ui/context_menu.gd`, `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- sizes from functions instead of constants, so one switch changes them all
- why pixel text steps between whole sizes instead of scaling smoothly

## 2026-11-10: Sound, ticket 1: the sound director, channels, clicks, and radio

Files: `scripts/audio/sound_synth.gd`, `scripts/audio/sound_set.gd`, `scripts/audio/sound_director.gd`, `data/sound_set.tres`, `scripts/ui/flight_hud.gd`, `scripts/ui/comms_line.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- audio buses (channels) made in code with AudioServer
- making sound from numbers: samples, sine waves, noise, envelopes, and a low-pass filter
- a pool of players reused round-robin for one-off sounds

## 2026-11-10: Sound, ticket 2: the ship through its hull, and haptics

Files: `scripts/audio/sound_director.gd`, `scripts/ship.gd`, `scripts/main.gd`

- looping sounds whose loudness and pitch follow the game (linear_to_db)
- an audio effect on a bus (a low-pass filter) standing in for hearing through a hull
- haptics with Input.vibrate_handheld, only on phones

## 2026-11-10: Sound, tickets 3 and 4: air and the suit

Files: `scripts/audio/sound_director.gd`, `docs/DESIGN.md`

- sound that depends on the medium: a filter's cutoff following the air's density
- mixing several causes into one loop (RCS or jetpack into the same hiss)

## 2026-11-10: Fix the re-entry crash, and quieter RCS

Files: `scripts/audio/sound_synth.gd`, `scripts/audio/sound_director.gd`

- off-by-one: an inclusive loop end reading one sample past the buffer
- reading a native crash log (tombstone) from `adb logcat -b crash`
- why a bug can crash on the phone and not the Mac (the allocator's guard pages)

## 2026-11-11: Suit breathing that doesn't sound like the RCS

Files: `scripts/audio/sound_synth.gd`, `scripts/audio/sound_director.gd`

- cascading low-pass filters for a darker sound
- measuring loudness with RMS

## 2026-11-11: Cut the suit's breathing

Files: `scripts/audio/sound_synth.gd`, `scripts/audio/sound_set.gd`, `scripts/audio/sound_director.gd`, `docs/DESIGN.md`

- removing a feature cleanly: every place it's named, not just turning it to zero

## 2026-11-11: Silent buttons, and a softer wind

Files: `scripts/audio/sound_director.gd`, `scripts/audio/sound_synth.gd`, `docs/DESIGN.md`

- a filter whose cutoff moves over time (gusts)
- keeping a loop seamless: every change repeats with the loop's length

## 2026-11-11: Crash sounds

Files: `scripts/ship.gd`, `scripts/audio/sound_synth.gd`, `scripts/audio/sound_set.gd`, `scripts/audio/sound_director.gd`, `docs/DESIGN.md`

- resonators (a two-pole filter that rings like struck metal)
- layering sounds by severity from one event's numbers
- scheduling things for later with a queue of callables

## 2026-11-11: Saving

Files: `scripts/save/save_game.gd`, `scripts/main.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/station/station_view.gd`, `scripts/gig/agency.gd`, `scripts/world_catalog.gd`, `scripts/ui/flight_hud.gd`, `docs/DESIGN.md`

- serializing state with `store_var` / `get_var`
- versioned saves and migrations
- atomic writes (write a spare file, then rename)
- Android app lifecycle notifications (`NOTIFICATION_APPLICATION_PAUSED`)

## 2026-11-11: Title screen

Files: `scripts/ui/title_screen.gd`, `scripts/ui/title_lettering.gd`, `scripts/flight_view.gd`, `scripts/main.gd`, `scripts/ui/flight_hud.gd`, `scripts/ui/flight_menu.gd`, `scripts/audio/sound_director.gd`, `scripts/screen_fit.gd`, `scripts/ui/ui_style.gd`, `tools/make_hud_font.gd`, `art/hud_font.png`, `docs/DESIGN.md`

- pausing the scene tree, and process modes that keep working while paused
- static variables that last across a scene reload
- solving for a camera's zoom, turn, and center from where two points should land on screen

## 2026-11-12: Title lettering as pixel art

Files: `scripts/ui/title_lettering.gd`, `scripts/ui/title_screen.gd`, `docs/DESIGN.md`

- painting into an `Image` at low resolution, then scaling it up with nearest filtering
- rasterizing shapes pixel by pixel (polygons, a rotated ellipse ring)
- layering with outlines to fake depth (in front of / behind)

## 2026-11-12: Title copied from the mockup

Files: `scripts/ui/title_lettering.gd`, `scripts/ui/title_screen.gd`, `docs/DESIGN.md`

- measuring a reference image's pixels from a script
- fitting an ellipse to measured points by searching for the least error
- defining shapes in a reference's own coordinates and sampling them at a lower resolution

## 2026-11-12: Zen Mode

Files: `scripts/main.gd`, `scripts/ui/title_screen.gd`, `scripts/save/save_game.gd`, `scripts/ship.gd`, `scripts/pilot.gd`, `scripts/audio/music_set.gd`, `scripts/audio/music_player.gd`, `data/music_set.tres`, `docs/DESIGN.md`

- one scene, two rule sets: flags that switch systems on and off
- a shuffle bag, so music never repeats back to back
- fading audio in and out with `linear_to_db`

## 2026-11-12: Prices and the service terminal

Files: `scripts/station/service_prices.gd`, `data/service_prices.tres`, `scripts/station/ship_services.gd`, `scripts/ui/service_board.gd`, `scripts/ui/flight_hud.gd`, `scripts/main.gd`, `scripts/ship.gd`, `scripts/ship/ship_body.gd`, `scripts/gig/agency.gd`, `scripts/pilot.gd`, `data/station_1.tres`, `tests/test_station.gd`, `docs/DESIGN.md`

- separating rules (ShipServices) from the screen that shows them (ServiceBoard)
- drawing a picture from data: a ship's pixels into an `Image`
- laying out labels with leader lines so they don't overlap

## 2026-11-12: Paid fuel at the launch base

Files: `scripts/site/site_building.gd`, `data/launch_base.tres`, `scripts/pilot.gd`, `scripts/station/ship_services.gd`, `scripts/ui/service_board.gd`, `scripts/ui/flight_hud.gd`, `scripts/ship.gd`, `scripts/ui/comms_line.gd`, `docs/DESIGN.md`

- reusing one screen in two places by passing where it is
- a precondition (the ship has to be there) that disables actions

## 2026-11-12: The Lander Mk II and the hangar

Files: `art/lander_mk2/`, `data/lander_mk2_design.tres`, `data/ship_list.tres`, `scripts/station/ship_list.gd`, `scripts/station/hangar.gd`, `scripts/station/ship_services.gd`, `scripts/ui/service_board.gd`, `scripts/ship.gd`, `scripts/reentry_glow.gd`, `scripts/save/save_game.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- rebuilding a node from new data at runtime (tearing down and recreating its children)
- keeping per-item state in a dictionary keyed by resource path
- refactoring shared code into helpers both a save and the hangar use

## 2026-11-12: Shock-absorbing landing legs

Files: `scripts/ship/module_data.gd`, `scripts/ship/ship_design.gd`, `scripts/ship/ship_body.gd`, `scripts/ship.gd`, `scripts/station/ship_services.gd`, `data/lander_mk2_design.tres`, `docs/DESIGN.md`

- a damped spring stepped each tick (semi-implicit Euler), and choosing stiffness and damping
- combining energies: safe speed as the square root of summed squares
- measuring a shape (the stance) instead of hard-coding it

## 2026-11-14: Mid-flight events, and uncharted signals

Files: `scripts/event/event_type.gd`, `scripts/event/flight_event.gd`, `scripts/event/event_director.gd`, `data/events/signal.tres`, `scripts/ui/event_list.gd`, `scripts/ui/event_markers.gd`, `scripts/ui/flight_hud.gd`, `scripts/flight_view.gd`, `scripts/world_catalog.gd`, `scripts/gig/agency.gd`, `scripts/save/save_game.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- seeded random rolls (a hash of the seed and a counter) so the same seed gives the same events
- a growing chance (pity timer) so long dry spells don't happen
- delegating by "kind" so one camera, card, and marker system handles a new type of thing
- upgrading a versioned save one step at a time

## 2026-11-14: Gigs back in Zen Mode

Files: `scripts/main.gd`, `docs/DESIGN.md`

- one rule changed in one place: wiring the same system in both modes instead of branching

## 2026-11-14: Distress beacons: grab their hand and tow them home

Files: `scripts/event/event_director.gd`, `scripts/event/flight_event.gd`, `scripts/event/event_scene.gd`, `scripts/event/survivor_view.gd`, `data/events/distress.tres`, `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/ship.gd`, `scripts/ui/comms_line.gd`, `scripts/ui/event_markers.gd`, `scripts/world_catalog.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- circular orbit velocity, sqrt(mu / r), and an orbit's direction from the cross product
- Newton's second law: the same push on twice the mass gives half the acceleration
- physics process priority: updating things in the right order within one tick
- GDScript lambdas capture variables by value (reassigning inside one doesn't change the outside)

## 2026-11-14: Passing comets

Files: `scripts/event/event_director.gd`, `scripts/event/event_type.gd`, `scripts/event/comet_view.gd`, `scripts/event/event_scene.gd`, `scripts/ui/event_markers.gd`, `data/events/comet.tres`, `docs/DESIGN.md`

- hyperbolic flybys: speed at closest pass from vis-viva, v² = v∞² + 2μ/r
- running an orbit backward in time (a negative time step) to find where something starts
- orbital period from the semi-major axis, T = 2π√(a³/μ)
- caching an expensive result and refreshing it on a timer

## 2026-11-14: Events list fits its space, and warp drops for news

Files: `scripts/ui/event_list.gd`, `scripts/ui/flight_hud.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- laying out a panel from the room left between its neighbors
- connecting one system's signal to another's method in the one place that knows both (main)

## 2026-11-14: Fewer runs of the same event

Files: `scripts/event/event_director.gd`, `docs/DESIGN.md`

- weighted random choice, with weights that change with what's already happened
- soak testing: running a long simulated flight fast to catch rare errors

## 2026-11-14: Steady orbit lines for events

Files: `scripts/event/event_director.gd`

- reference frames: keeping a path relative to the body it orbits, then adding the body's position when drawing

## 2026-11-14: The pilot's size inside stations

Files: `scripts/pilot.gd`, `docs/DESIGN.md`

- keeping what's drawn and what collides at the same scale

## 2026-11-14: Lighting, ticket 1: lamps in stations

Files: `shaders/palette_light.gdshaderinc`, `shaders/interior_light.gdshader`, `scripts/palette_light.gd`, `scripts/station/station_design.gd`, `scripts/station/station_room.gd`, `scripts/station/station_layout.gd`, `scripts/station/station_view.gd`, `docs/DESIGN.md`

- shader includes (.gdshaderinc) to share code between shaders
- palette ramps: shading by stepping colors down a lookup instead of multiplying toward black
- ordered (Bayer) dithering
- uniform arrays filled from GDScript

## 2026-11-14: Lighting, ticket 2: lamps stay in their rooms

Files: `scripts/station/station_light.gd`, `scripts/station/station_layout.gd`, `scripts/station/station_view.gd`, `shaders/interior_light.gdshader`, `docs/DESIGN.md`

- baking: working out something expensive once into a texture
- WorkerThreadPool: running slow work on another thread and picking up the result
- blending light like a screen blend (1 - (1-a)(1-b)) so it never passes full

## 2026-11-14: Lighting, ticket 3: the helmet lamp

Files: `shaders/interior_light.gdshader`, `scripts/station/station_view.gd`, `scripts/pilot.gd`, `scripts/pilot/astronaut_view.gd`, `docs/DESIGN.md`

- ray marching through a mask texture in a fragment shader for shadows
- a cone test with the dot product and smoothstep for soft edges
- hysteresis: separate on and off thresholds so a switch doesn't flicker

## 2026-11-14: Lighting, ticket 4: power, emergency lamps, and failing lamps

Files: `scripts/station/station_light.gd`, `scripts/station/station_view.gd`, `scripts/station/station_design.gd`, `shaders/interior_light.gdshader`, `scripts/ui/flight_menu.gd`, `scripts/ui/flight_hud.gd`, `scripts/feature_flags.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- packing separate data into a texture's color channels
- animating a shader through uniforms (a pulse and a random sputter) instead of redrawing
- a debug switch behind a feature flag

## 2026-11-14: Lighting outside, ticket 1: ships lit by the star

Files: `shaders/hull_light.gdshader`, `scripts/ship/hull_light.gd`, `scripts/ship.gd`, `docs/DESIGN.md`

- faking a 3D normal from a 2D sprite (a cylinder per run of pixels)
- Lambert (dot product) lighting, with wrap so shading rolls round
- turning a world direction into a sprite's own space by its global rotation

## 2026-11-14: Lighting outside, ticket 2: a world's shadow

Files: `scripts/sunlight.gd`, `scripts/ship.gd`, `docs/DESIGN.md`

- a shadow as a cylinder behind a sphere: projecting onto the star's direction (dot) and measuring the distance off that axis (cross)
- smoothstep for a soft edge (a penumbra)

## 2026-11-14: Lighting outside, ticket 3: the station and the pilot

Files: `scripts/ship/hull_light.gd`, `shaders/hull_light.gdshader`, `scripts/station/station_view.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/pilot.gd`, `scripts/event/survivor_view.gd`, `docs/DESIGN.md`

- choosing a surface's curve from the shorter of two runs (a cheap guess at a shape's axis)
- aiming a 3D light from a 2D screen direction
- doing big image work on a worker thread and swapping the result in

## 2026-11-14: Lighting outside, ticket 4: the engine's light, and the hangar picture

Files: `shaders/hull_light.gdshader`, `scripts/ship.gd`, `scripts/ship/hull_light.gd`, `scripts/palette_light.gd`, `scripts/ui/service_board.gd`, `docs/DESIGN.md`

- a point light in a sprite's own pixel space
- the same lighting worked out on the CPU for a picture drawn as part of a bigger one
- refactoring shared logic so the shader's table and the code's come from one place

## 2026-11-14: Death, ticket 1: how the pilot dies

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/main.gd`, `scripts/audio/sound_director.gd`, `scripts/event/event_director.gd`, `docs/DESIGN.md`

- quadratic drag and terminal velocity (v = sqrt(2mg / (rho A)))
- thresholds as bands (safe, hard, fatal) instead of one cutoff
- turning a character into a passive physics body when it dies (a simple ragdoll stand-in)

## 2026-11-14: Death, ticket 2: the suit's air

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/pilot/astronaut_model.gd`, `scripts/ui/tank_gauges.gd`, `docs/DESIGN.md`

- a resource that drains by rate times count (holes) and refills on an event
- recoil: venting gas pushes the other way (Newton's third law)
- swapping a 3D mesh's material at runtime

## 2026-11-14: Death, tickets 3 and 4: the med bay and getting a ship back

Files: `scripts/station/med_bay.gd`, `scripts/ui/med_bay_board.gd`, `scripts/station/service_prices.gd`, `scripts/ui/flight_hud.gd`, `scripts/gig/agency.gd`, `scripts/save/save_game.gd`, `scripts/pilot.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- a pure function for a bill (inputs in, a dictionary out) that's easy to test
- saving a pending event at once so quitting can't undo it, and charging it only once (idempotency)
- a timer (SceneTree.create_timer) for a delay before the next step

## 2026-11-14: Death, ticket 5: going down with the ship

Files: `scripts/pilot.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- one code path for several ways in (both deaths reach the med bay through one function)

## 2026-11-14: Settings

Files: `scripts/game_settings.gd`, `scripts/ui/settings_screen.gd`, `scripts/ui/title_screen.gd`, `scripts/ui/flight_menu.gd`, `scripts/ui/flight_hud.gd`, `scripts/audio/sound_director.gd`, `scripts/pilot.gd`, `scripts/main.gd`, `docs/DESIGN.md`

- ConfigFile for small settings files in user://
- audio buses: volume in decibels from a linear share (linear_to_db), and muting
- static variables as a simple shared store without an autoload
- set_input_as_handled so a screen on top takes the touches

## 2026-11-14: Moon Hopper ticket 1, a centered engine's tail nozzles

Files: `scripts/ship/ship_body.gd`, `scripts/rcs_puffs.gd`, `docs/LEARNING_LOG.md`

- mirroring a point and a rect across a module's own middle
- one pixel set (both nozzle rects) driving one share, so the pair works or fails together

## 2026-11-14: Moon Hopper ticket 2, a ship numbers tool

Files: `tools/ship_numbers.gd`, `docs/LEARNING_LOG.md`

- a headless command-line script (SceneTree, OS.get_cmdline_user_args after `--`)
- delta-v from the rocket equation, exhaust velocity times ln of full over dry mass

## 2026-11-14: Moon Hopper ticket 3, bring in the Moon Hopper

Files: `art/moon_hopper/*.png`, `data/moon_hopper_design.tres`, `data/ship_list.tres`, `tests/test_moon_hopper.gd`, `docs/DESIGN.md`, `docs/LEARNING_LOG.md`

- materials read from art color, so the game's mass differs from the editor's explicit one
- setting engine and RCS numbers from measured mass (thrust over weight, delta-v)
- awaiting a frame in a test so a scene's nodes are ready

## 2026-11-14: Comet look ticket 1, the nucleus

Files: `shaders/comet_nucleus.gdshader`, `scripts/event/comet_view.gd`, `scripts/event/event_type.gd`, `scripts/event/event_scene.gd`, `scripts/main.gd`, `data/events/comet.tres`, `docs/briefs/comet_look.md`, `docs/LEARNING_LOG.md`

- a canvas_item shader drawn over a quad, with uniform arrays (bulges, craters) filled from seeded code
- shading a flat disc as a lumpy sphere: height from the radius, a normal, a dot with the light
- 4 x 4 Bayer dither between banded tones, on a game-pixel grid kept square to the screen under view roll
- seeding from a name hash so the same comet always looks the same

## 2026-11-14: Comet look ticket 2, the coma and both tails

Files: `shaders/comet_glow.gdshader`, `scripts/event/comet_view.gd`, `docs/DESIGN.md`, `docs/LEARNING_LOG.md`

- rewinding a copy of a state with a negative `propagate` to get a path behind a moving body
- distance to a polyline in a shader (nearest point on each segment, and how far along it is)
- a vec2 array uniform carrying a path to a fragment shader, and clipping a huge quad to the screen
- 1D value noise for streamers, and cutting a strength into 5 alpha bands with a Bayer dither

## 2026-11-14: Thin the comet's glow up close

Files: `scripts/event/comet_view.gd`, `docs/LEARNING_LOG.md`

- fading by zoom on a log scale (`log`, `lerpf`, `clampf`)
- a static function so a rule can be checked without a scene

## 2026-11-14: Falling and dying ticket 1, blend poses and looks

Files: `scripts/pilot/astronaut_view.gd`, `tests/test_pilot_pose.gd`, `docs/LEARNING_LOG.md`

- a damped spring (omega, zeta) stepping a value toward a target, in small slices so a long frame stays stable
- critical damping (zeta 1) against underdamping (zeta below 1) for overshoot and wobble
- quaternion slerp with a smoothstep ease, to blend between two camera angles
- target value versus shown value: computing a pose, then easing the joints toward it

## 2026-11-14: Falling and dying ticket 2, the fall view and the flail

Files: `scripts/pilot.gd`, `scripts/pilot_data.gd`, `scripts/pilot/astronaut_view.gd`, `tests/test_pilot_pose.gd`, `docs/LEARNING_LOG.md`

- a static function that takes plain numbers, so a rule (the fall view) can be tested without a scene
- orbit apsides as a "will this hit the ground" test, and a path that never comes back
- smoothstep as an honest 0 to 1 share from a speed range
- latching a value (which way they face) and only changing it past a threshold
- easing a pixel offset to nothing, so a change of view doesn't pop

## 2026-11-14: Falling and dying ticket 3, dying blends

Files: `scripts/pilot.gd`, `scripts/pilot/astronaut_view.gd`, `scripts/pilot/astronaut_pixels.gdshader`, `tests/test_pilot_pose.gd`, `docs/LEARNING_LOG.md`

- a toppling plank as angular acceleration scaled by gravity, with one bounce at a fifth of the speed
- taking the higher of two heights (resting and sinking) and never letting it rise, to settle without a jump
- ordered (Bayer 4 x 4) dither in a canvas_item shader, to flare to glow colors and dissolve a sprite
- a timer-driven fade (plume strength) and a state flag (resting) set once when a body first touches down
- a fixed-step simulation in a test to check a per-frame limit

## 2026-11-14: Falling and dying fix pass, soles at contact, free-fall settle, bigger flail

Files: `scripts/pilot.gd`, `scripts/pilot/astronaut_view.gd`, `tests/test_pilot_pose.gd`, `docs/LEARNING_LOG.md`

- free fall as speed plus g times time, so a settling body keeps its impact speed instead of braking
- lowering a drawn sprite by the gap between where contact is detected and where the soles are, scaled by cosine of the tilt
- carrying an easing offset across a mode change so the drawn position stays continuous
- why a headless harness can mislead: a hidden node doesn't run its process, so a phase never advanced
- exaggerating a pose for a small sprite (bigger arcs, a body rock) and checking it by screenshot

## 2026-11-14: Several gigs ticket 1, the agency holds several gigs

Files: `scripts/gig/agency.gd`, `scripts/ship.gd`, `scripts/save/save_game.gd`, `scripts/ui/flight_hud.gd`, `tests/test_gigs.gd`, `docs/LEARNING_LOG.md`

- iterating over a copy of an array when the loop removes items from it
- one shared timer for a check, so several things waiting on it don't each speed it up
- a versioned save upgrade step (version 2 to 3) that reshapes one entry into a list
- a default argument as a sentinel (-1 means "all") so old callers keep working

## 2026-11-14: Several gigs ticket 2, the tracker and HUD show several

Files: `scripts/ui/gig_tracker.gd`, `scripts/ui/flight_hud.gd`, `docs/LEARNING_LOG.md`

- a widget that works out which part of itself a tap landed on (header, a row, or nothing) from the tap's y
- a signal from a child widget (gig_picked) so the HUD, not the widget, talks to the agency
- a pool of marker nodes, one per slot, shown or hidden each frame instead of made and freed
- telling "just taken" from "already held" by remembering the ids held at the last change

## 2026-11-14: Several gigs ticket 3, the board for several gigs

Files: `scripts/ui/gig_board.gd`, `tests/test_gigs.gd`, `docs/LEARNING_LOG.md`

- a "just did it" flag that locks a button until the player does something else, so a double tap can't repeat it
- re-reading a list from its source (refresh) after changing it, so a replaced row shows at once
- a UI widget that only lays itself out when it draws, and what that means for driving it in a headless test

## 2026-11-14: No dithering ticket 1, palette lighting without dither

Files: `shaders/palette_light.gdshaderinc`, `shaders/hull_light.gdshader`, `shaders/interior_light.gdshader`, `scripts/palette_light.gd`, `scripts/ship/hull_light.gd`, `docs/LEARNING_LOG.md`

- snapping to the nearest step with floor(x + 0.5) instead of a threshold pattern
- replacing a noise threshold with its average (0.5) so band positions stay put
- dropping an unused function argument from a shader helper and all its callers

## 2026-11-14: No dithering ticket 2, sky, planets, star, re-entry and comet without dither

Files: `shaders/planet.gdshader`, `shaders/star.gdshader`, `shaders/reentry.gdshader`, `shaders/comet_glow.gdshader`, `shaders/comet_nucleus.gdshader`, `scripts/event/comet_view.gd`, `docs/LEARNING_LOG.md`

- folding a dither's average into a constant (1 - 0.4 + 0.5 * 0.4 = 0.8) so the band positions stay put
- a shader parameter that only fed a removed pattern is deleted, not left dead
- how to tell a shader really compiled: a throwaway script that draws it in a window, since headless runs never build shaders

## 2026-11-14: No dithering ticket 3, the pilot burning up and a last sweep

Files: `scripts/pilot/astronaut_pixels.gdshader`, `scripts/pilot/astronaut_view.gd`, `scripts/ground_effects.gd`, `docs/LEARNING_LOG.md`

- a dissolve over time as a hard line compared against UV.y, instead of a per-pixel threshold
- keeping only the middle share of a strip of columns by distance from its centre
- sweeping a codebase with grep for leftover patterns after a rule change

## 2026-11-14: New Kapteyn-3 ticket 1, modules in data and the layout

Files: `scripts/station/station_module.gd`, `scripts/station/station_port.gd`, `scripts/station/station_prop.gd`, `scripts/station/prop_placement.gd`, `scripts/station/light_fixture.gd`, `scripts/station/outside_light.gd`, `scripts/station/station_design.gd`, `scripts/station/station_layout.gd`, `tests/test_station.gd`, `docs/DESIGN.md`, `docs/LEARNING_LOG.md`

- resources as data: small `Resource` classes with `@export` fields, so a station is a file and not code
- quarter turns of pictures and points (rotating an image and the points on it the same way)
- layers composed with `Image.blend_rect`, and a walkable mask worked out from them
- a texture can hand out its own image, so turning it needs a copy
- building a synthetic test fixture in code instead of loading art
