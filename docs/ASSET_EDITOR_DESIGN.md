# Final Orbit Asset Editor — Design Document

Date: November 8, 2026, revised November 9, 2026  
Owner: Emmanuel Walters  
Builders: GPT builds the editor application. Claude builds the game and its integration of exported assets.  
Status: Revised after review; implementation has not started

## 1. Purpose

Final Orbit Asset Editor is a standalone desktop application, built in Godot, for creating the visual and physical assets used by Final Orbit.

It turns generated concept images, existing pixel art, and programmatic drawing into reusable parts, assembled ships, station rooms, and stations. It also provides a workspace for authoring procedural planets, moons, and stars.

The application makes appearance, construction, and gameplay properties explicit. Artwork no longer determines material through its visible color. People and LLMs operate on the same editable documents through the same editing engine.

The initial workflow starts with PNGs supplied by the user, including images generated with Gemini. Image generation is optional: an LLM can also draw through structured operations and assemble assets from a reusable part library.

The editor must support the eventual construction of ships inside the game. Its core content model is:

**Part definitions → assembly blueprints → live game instances.**

## 2. Decision status and authority

- **Agreed:** requirements and scope established in the planning conversation and its review.
- **Proposed:** implementation choices recommended here, to be proven during the first integration milestone.
- **Future:** supported direction that is outside the initial implementation.
- **Excluded:** explicitly removed from this editor's scope.

This document describes the asset editor and the game integration it will require. It does not authorize implementation changes to the game by itself. The existing game design remains in `docs/DESIGN.md`; changes to its material, construction, and damage rules should be recorded there when implemented.

The request for in-game ship building was exploratory. Designing reusable parts and blueprints now is the proposed foundation; shipping an in-game builder remains a separate game feature.

## 3. Product form and architecture

**Agreed (revised 2026-11-09):** a standalone desktop application built from the same Godot project as the game.

The user launches a dedicated editing application. Its interface is designed around asset creation and does not require navigating the Godot development interface. Sharing the game's project is what guarantees that both use one implementation of physics, material, and construction rules, which two separate Godot projects cannot do without copying code.

The architecture has three pieces, in three folders of the one project:

| Piece | Folder | Responsibility |
| --- | --- | --- |
| Editor application | `editor/` | Import, image cleanup, mask and material painting, touch-up pixel editing, component authoring, assembly, sealing validation, pressure preview, export, the CLI, and the MCP wrapper |
| Shared core | `core/` | Documents, definitions, commands, serialization, material interpretation, construction calculations, seal logic, and atmosphere calculations. No UI, and usable headless |
| Game integration | the game's existing folders | Load exported assets, instantiate assemblies, and apply the game's movement, damage, interaction, and persistence behavior |

How it's built and run:

- **Agreed:** Godot 4.7.2 with the Compatibility renderer, the game's version, on macOS first. Other desktop targets can follow.
- **Proposed:** a custom feature tag, `asset_editor`, selects the editor's main scene through a project-setting override (`application/run/main_scene.asset_editor`). A macOS export preset with that feature builds the app. In development, run the editor's scene directly.
- The Android export excludes `editor/*`, the same way it already excludes `tests/*`. It keeps `core/*`, since the game uses it.
- The game's window settings (816 × 616 viewport, integer stretch) stay as they are. The editor's main scene sets its own window and stretch at startup, or uses `asset_editor` feature overrides.
- The game has no autoloads, and the editor must not add any, since autoloads run in every build. Editor-wide state lives under the editor's main scene.
- `class_name` is global across the project. Editor classes are prefixed `Editor`, and core classes are prefixed `Core` unless they replace a game class by agreement. The game's current class names are listed in the handoff notes.
- The headless CLI runs as `godot --headless --path . --script res://editor/cli.gd -- <command>`.

Collaboration rules are in section 20.

## 4. Goals and scope

### Agreed capabilities

- Import generated PNG artwork and existing pixel art.
- Clean backgrounds, recover a pixel grid, align layers, snap to the palette, and touch up pixels.
- Author exterior, systems, and structural artwork with explicit material assignments per physical depth.
- Define functional components and their working regions.
- Create reusable parts and assembled object blueprints.
- Author station and multiroom ship interiors, doors, compartments, and pressure boundaries.
- Validate sealing and preview pressure loss after a breach.
- Support structural connections, docking interfaces, and moving parts.
- Expose structured editing and inspection to Claude, Codex, and other clients through a CLI first, and MCP over the same handlers.
- Preserve editable source projects and export reproducible game assets.
- Report asset complexity and resource usage relevant to the game's mobile target.
- Author individual celestial bodies in the same application.

### Explicit exclusions

- A general behavior-testing workspace for flight, landings, collisions, and combat scenarios.
- A game-capability compatibility matrix or feature-requirement checker.
- Electrical, fuel-line, and air-duct equipment networks.
- **Agreed (2026-11-09):** a general-purpose pixel-art painting suite. Aseprite stays the drawing tool, as the game's art pipeline already says. The editor imports its output and only needs the painting operations that masks and small touch-ups require.

These exclusions do not remove basic file/schema validation, geometry checks, calculated asset statistics, sealing checks, or the specifically requested pressure preview. They also do not remove automated development tests of the shared core.

### Future or separate work

- The player-facing in-game ship builder.
- Construction during flight, salvage assembly, and pixel-level in-game construction.
- Full star-system assembly and physically constrained universe generation.
- Detailed fluid dynamics, per-pixel gas simulation, and aerodynamic forces on occupants or loose objects.
- Complete station destruction, atmosphere gameplay, and life-support implementation in the game.
- Advanced animation authoring.

## 5. Current game baseline

This baseline was established by read-only inspection of the working project on November 7–8, 2026, and checked against the code on November 9. The uncommitted local edits to data files found then were Godot editor re-saves: default values dropped and resource UIDs added, with no values changed.

### Ships

- `ShipDesign` contains modules, material resources, propulsion values, and interaction positions.
- `ModuleData` contains artwork, placement, fuel capacity, rectangular working regions, and moving-part information.
- The lander uses eight 64×64 grid modules and two separately cropped landing legs.
- `ShipBody` maps exact RGB colors to materials, through each material's list of palette colors, then sums density and strength over the exterior, systems, and frame depths.
- Artwork alpha currently controls whether an exterior pixel exists; underlying depths are only considered beneath those exterior pixels.
- Fuel capacity is explicit data. Fuel contributes mass and inertia. Thrust and exhaust velocity are explicit data.
- Damage removes material depths, updates mass, and eventually removes whole pixel columns. Detached pieces become debris.
- Collision uses a mixture of pixel lookup and generated outline approximations. Connectivity includes automatic welds across artwork gaps.
- Propulsion, flame placement, RCS classification, terrain sampling, and collision ranges contain lander-specific assumptions.

Read-only calculations from the current lander assets give approximately 19,491 kg dry mass, 40,000 kg fuel capacity, 300 m/s² acceleration when full, and 16,738 m/s ideal remaining delta-v when full.

### Stations

- `StationDesign` and `StationRoom` define room artwork, port connections, walkable rectangles, interaction points, and orbit settings.
- Exterior and interior sprites share a canvas. Rooms assemble through ports using quarter turns.
- Exterior alpha defines station solidity. Interior walking areas are separate annotations.
- Station art currently uses two world units per art pixel; ship art uses one.
- Stations follow prescribed orbits, turn with their orbit, are not destructible, and have no finite fuel supply or simulated construction mass affecting movement.
- Boarding reveals the interior by fading the roof artwork. This is a view change, not physical roof removal.

### Celestial bodies

- Planets and moons use `BodyData`; stars use `StarData`.
- Data resources supply physical and visual parameters. Shaders draw bodies; native terrain code supplies landing heights.
- The current system is manually assembled from one star, one planet, and one moon. Seeded terrain exists; the full universe-generation chain does not.
- Star temperature, color, and heating distance are currently independent settings.

### Scale

The HUD reads one world unit as one meter, but the pilot sprite is about 40 px tall, which at one world unit per art pixel would make the pilot 40 m tall. Read the other way, the pilot implies roughly 5 cm per pixel. The lander is 211 px tall, so either it is 211 m tall and weighs 19.5 t dry, or it is about 10 m tall. The game has never had to resolve this. Volumes and gas masses will, so it is the first open decision in section 21.

### Palette

The game's agency palette resource holds 25 colors. `docs/DESIGN.md` and `CLAUDE.md` say 26, which looks like a miscount of the table they contain. Twenty-two of the 25 have ship-material mappings; the three thrust colors are for flames only.

### Existing conversion tools

`tools/slice_lander.gd`, `tools/slice_station.gd`, and `tools/slice_pilot.gd` demonstrate useful import operations, but their crop regions, sampling assumptions, and alignment rules are tailored to the existing assets. `slice_station.gd` and `slice_pilot.gd` already recover a fake-pixel grid from concept art, remove backgrounds and stars, snap to the palette in Oklab, smooth shading speckle, restore the 1 px outline, and line frames up on an anchor. They are the starting point for the importer.

### Existing tests

- `tests/test_gravity_model.gd`, `tests/test_ship_body.gd`, and `tests/test_station.gd` run headless with `godot --headless --path . --script tests/<name>.gd` and print `N checks, M failed`.
- The game's own scene checks live outside the repository for now.

## 6. Content model

### 6.1 Part definitions

A part is a reusable authored object: an engine assembly, cockpit, tank, hull section, landing leg, corridor, room, or station hub.

Each definition has a stable ID, revision, name, local coordinate system, physical scale, visual layers, physical layers, and applicable components or connectors.

A part may occupy several grid cells and may contain several functional components. A component's identity must not be determined by which 64-pixel cell its artwork happens to occupy.

Grid snapping remains useful for placement. Internal runtime chunking may use fixed cells for efficiency, but it must preserve the authored identities of parts and components.

### 6.2 Assembly blueprints

A blueprint references part definitions at specific revisions and stores:

- A stable instance ID for every placed part.
- Position and supported orientation of each part.
- Structural and port connections between parts.
- Explicit permitted overrides, such as livery or selected configuration.
- The resolved compartment connections and relevant assembly metadata.

**Proposed initial rule:** integer-grid placement and quarter-turn rotations. Mirroring is permitted only when all artwork, material maps, component directions, hinges, and connectors transform consistently. Arbitrary-angle placement is deferred.

Pixel art is shaded for one light direction, so a part turned 90° or mirrored is lit from the wrong side. A part may supply its own artwork for each orientation it allows; without one, the editor turns the default artwork and notes it in diagnostics.

A blueprint uses one pixel scale. Placing a part drawn at a different scale, such as a station room at two world units per pixel in a ship drawn at one, is an error until rescaling rules exist.

Complete ships and stations are saved blueprints. Library presets use the same format as user-authored assemblies.

### 6.3 Live instances

A game instance references a blueprint and separately stores mutable state: damaged or missing material, fuel, door state, compartment gas, and other gameplay state.

Moving, repairing, or reassembling parts must preserve their instance IDs and state where appropriate. Reassembly must not implicitly refill tanks or restore destroyed pixels. Changes to a library part must not silently rewrite existing blueprints or live ships.

The game does not save yet, so instance persistence is game work that follows saving. The editor may eventually inspect instance snapshots. Full save-game editing is not an initial requirement.

## 7. Artwork and physical layers

The default ship damage stack remains exterior skin, systems, then structural frame. Start with these three physical depths rather than implementing an arbitrary volumetric model.

Each physical depth has:

- Optional associated appearance artwork.
- A material-ID map, with a reserved empty value.
- A thickness value, initially per layer or region.
- Relevant component membership and pressure-boundary associations.

The Materials editor is an overlay on the selected physical depth. It is not a single fourth slab of matter added to the ship. Overlay colors are editing aids; the exported values are material identifiers.

Visible material appearance and physical composition are independent. Painting aluminum orange changes the image, not its density.

### 7.1 What you see is what you hit

**Agreed (2026-11-09):** the game's rule that a ship's pixels are its collision and damage stays the default.

- An exterior pixel is physically occupied exactly where the exterior artwork is opaque, unless the region is flagged otherwise. Systems and frame maps default to their artwork's coverage beneath the exterior, as they do now.
- Two flags allow the two to differ on purpose: **decorative** (visible, no physics: antennas, decals, glow) and **hidden structure** (physics, not visible from outside: an internal bulkhead).
- Any other mismatch between artwork coverage and physical occupancy is an error. Export refuses to proceed until each mismatched region is flagged or fixed.
- Removing an outline from the drawing does not remove a structural member unless its physical map is edited too.
- Damage must stay readable. When a decorative pixel's supporting physical pixel underneath is destroyed, the decorative pixel goes with it. When hidden structure is destroyed, the game shows its loss as sparks and debris even though no artwork disappears.

A station interior cutaway is a viewing mode. Showing it does not delete physical roof material, remove collision, or vent the compartment.

Every aligned map shares explicit canvas dimensions, origin, and pixel scale. Cropping or resizing must transform associated maps and anchors together. The editor must distinguish adding visual detail from changing the physical size of a part.

## 8. Materials, dimensions, and calculated values

Materials have stable IDs and shared definitions for mass contribution and destruction strength. The palette remains an artistic rule, independent of these definitions.

**Proposed migration:** initially preserve the game's calibrated density-per-pixel and strength-per-pixel behavior at a declared reference cell size. Do not silently reinterpret the current lander as a physically scaled three-dimensional vehicle.

Before implementing physical volume and pressure calculations, the scale decision in section 21 must be made and recorded in `docs/DESIGN.md`. Compartment heights or explicit volumes and effective breach areas must be authored in its units. If later materials use volumetric density, the conversion and treatment of thickness must be explicit and versioned.

The editor displays derived dry mass, fueled mass, center of mass, inertia, fuel capacity, and supported propulsion estimates. Physical layers contribute dry mass; stored fuel and gas contribute their own consumable mass where supported. Tank capacity is not counted as solid tank material.

Color detection may remain an optional import suggestion and a migration aid. Once explicit material maps exist, they are authoritative.

The editor uses the palette resource's actual 25 entries and never invents a 26th.

## 9. Components, connections, and moving parts

Components identify functional regions independently of grid slicing. A component can cover multiple cells or multiple regions of a part.

Initial component definitions cover cockpit, engine, RCS thruster, tank, hull, landing gear, hatch, door, and interaction point as needed for the migration and agreed workflows.

Engine and thruster definitions include their working mask, application position, exhaust position, direction, force, and relevant fuel-use parameters. Tank definitions include capacity and the region whose destruction affects containment. Existing gameplay behavior should be preserved during migration before introducing new failure rules.

Structural connectors describe attachment locations, compatible geometry, joint type, and strength where supported. Automatic artwork-gap welding should be replaced by explicit construction intent. The importer may still suggest welds across small gaps, which the author accepts or rejects.

Docking and room interfaces describe port geometry, facing, clearance, and intended joins. Structural attachment, an airtight join, and a traversable doorway are distinct properties.

Moving parts have local transforms, pivots, allowed motion, and connection information. Initial support should cover the current landing legs and required door states. Decorative movement must not accidentally change structural attachment or sealing.

Ships and stations share construction definitions. Their movement models and services remain separate; adopting damageable construction does not require making stations free-flying ships.

## 10. Interiors, sealing, and atmosphere

### 10.1 Authored geometry

Compartment regions represent spaces containing gas. Walkable regions represent places a pilot can occupy. These masks are separate: equipment can block movement without eliminating the air around it.

Pressure boundaries identify which intact hull, roof, floor, window, or bulkhead layers seal a compartment. A top-down room can leak through its roof or floor even when its perimeter is closed. The data must model these exposed surfaces explicitly.

A breach exists only when an opening connects gas volumes or connects a gas volume to space. Losing exterior paint or non-sealing plating alone does not constitute a breach. For layered barriers, the system must determine whether a continuous opening passes through the remaining sealing layers.

This is an explicit 2D construction model with authored depth and exposure information. It cannot infer or certify the sealing of an unspecified three-dimensional object from a picture.

### 10.2 Seal validation

The editor checks individual parts and complete assemblies in specified door and hatch states. It highlights unintended paths to space, incomplete boundaries, invalid joins, and disconnected or unassigned compartment regions.

The geometry contract must define corner adjacency and diagonal gaps. Structural corner contact and gas connectivity must not accidentally inherit the same rule. Boundary and opening tests live in the shared core and are used by the game.

A valid airlock may be intentionally depressurized. The check compares the assembly with the intended configuration rather than insisting that every room is always pressurized.

### 10.3 Pressure preview

**Agreed:** provide a focused preview for opening or damaging boundaries and watching compartment pressure and oxygen change. Users can operate doors, introduce a breach, close or repair an opening, and inspect connected compartments.

**Proposed model:** a network of internally well-mixed compartments. Each has volume, gas quantities, and temperature. Edges represent doors and openings; space is an external vacuum boundary. Destruction may create edges, merge or split compartment regions, or expose a compartment to space.

**Proposed first approximation:** isothermal ideal gas, with orifice flow through each opening.

- Venting to vacuum is always choked, so the mass flow is proportional to the upstream pressure: ṁ = C·A·p, with C = C_d·√(γ/(R·T))·(2/(γ+1))^((γ+1)/(2(γ−1))). A single room venting to space therefore decays exponentially, with a time constant of V/(C·A·R·T).
- Between two rooms, use the choked form while the downstream-to-upstream pressure ratio is below the critical ratio (about 0.528 for air), and the subsonic orifice form above it.
- Integrate with steps bounded by the smallest active time constant, so small rooms behind large openings stay stable.

Transfers must conserve gas between compartments and must not produce negative gas quantities. At room-graph scale this is cheap enough for the phone.

Track oxygen quantity separately from total gas quantity, so total pressure and oxygen availability are not conflated. The thermal assumption is stated in the preview; it is a first approximation, not a claim of complete thermodynamic realism.

Repair closes an opening but does not automatically replace lost gas. Initial gas conditions and optional explicit refill controls are sufficient for authoring preview. Equipment networks and detailed life support are outside scope.

The preview should show pressure, oxygen fraction and partial pressure, flow direction, and affected compartments. Estimated times are model outputs, not guarantees of real-world behavior. Avoid inventing crew-safety thresholds before gameplay rules are chosen.

The atmosphere implementation lives in the shared core and later drives game pressure behavior. The editor must not develop a separate approximation that disagrees with the game.

## 11. Image import and editing workflow

1. Create or open a part, assembly, or celestial-body document.
2. Import a source PNG, layered PNGs exported from Aseprite, or begin with a blank canvas or reusable part.
3. Select the drawing regions and target scale. Recover the source pixel grid where appropriate.
4. Remove background, labels, stars, and other unwanted content using adjustable suggestions and manual correction.
5. Convert visible colors to the palette and repair edges. Preserve thin intended details.
6. Import and align systems, structure, and interior artwork as applicable.
7. Assign physical occupancy, materials, and thickness. Bulk fills and reusable templates should reduce repetitive painting.
8. Define components, connectors, moving parts, compartments, and interaction points.
9. Inspect the assembled result, calculated values, and applicable seal/pressure results.
10. Save the editable source project and export a game asset bundle.

### Drawing

Drawing new artwork happens in Aseprite. The editor round-trips with it: it imports a PNG per layer, or Aseprite's sprite-sheet PNG with its JSON, and can export the current artwork the same way for repainting.

The editor's own painting operations exist for masks and touch-ups: brush, erase, fill, rectangle, line, palette snap, outline generation, and undo/redo. They work the same on artwork and on integer maps such as materials, compartments, and walkable regions. Polygons, selection transforms, and mirroring are added only when a mask workflow needs them.

Include visibility and opacity controls for reference layers, and clear coordinate feedback.

A generated image may contain inconsistent pixel sizes, perspective, or ambiguous interiors. The importer must expose its assumptions and allow correction. It cannot reliably infer structural materials, fuel capacity, or airtight compartments from appearance alone.

Original images remain available as references. Replacing artwork must preserve annotations whenever their coordinates remain valid, and visibly identify annotations affected by a deliberate canvas transformation.

## 12. LLM access and automation

**Agreed:** provide a CLI and MCP access to the same editing engine used by the visual application. The tool does not require an image-generation model or a built-in chat interface.

**Agreed (2026-11-09):** the CLI comes first, before the visual application. It is the path an LLM uses to import and convert art, and it is useful to the game before any UI exists. MCP is a thin wrapper over the CLI's command handlers.

Clients can create geometry, draw pixels and shapes, use procedural details, place library parts, assign material regions, define components, assemble blueprints, inspect values, validate seals, preview pressure, and export artifacts.

Commands operate on stable IDs and bounded selections rather than UI coordinates or ad hoc file rewriting. Example operation families:

- `document.create`, `document.inspect`, `document.save`
- `import.image`, `import.recover_grid`, `import.remove_background`, `import.snap_palette`
- `art.draw_polygon`, `art.fill`, `art.replace_colors`
- `physical.assign_material`, `physical.set_thickness`
- `component.create`, `component.set_working_mask`
- `assembly.place_part`, `assembly.connect`, `assembly.remove_part`
- `compartment.create`, `boundary.assign`, `door.set_state`
- `seal.validate`, `pressure.preview`, `preview.render`, `asset.export`

Names above illustrate the interface; they are not a finalized API schema.

### Revisions and concurrency

**Proposed:** documents live on disk, each with a revision number.

- Every mutating batch names the revision it was based on and commits atomically, writing the new revision. A stale revision produces a conflict instead of overwriting newer edits.
- The visual application and the CLI both commit through the same core command handlers, so neither needs to be running for the other to work.
- The visual application watches its open documents and reloads when another client commits. Undo in the application covers its own transactions and any reloaded external commit as one step.

Return structured results with changed IDs, diagnostics, calculated values, and optional rendered previews. Clients should be able to inspect small regions and summaries without repeatedly retrieving entire pixel arrays.

Export and deployment are distinct operations: saving or editing an asset must not silently overwrite a live game asset.

**Proposed:** keep the automation endpoint local and bind its access to explicitly opened projects or configured output directories. Generated content and imported metadata remain data, never executable instructions.

## 13. Interface organization

The primary workspace has an asset library, canvas, layer/overlay controls, properties inspector, and diagnostics panel.

Constructed-object views include exterior, systems, structure, interior, materials, components, connections, and compartments. Views are projections of the same document rather than independent copies.

Assembly mode places parts and displays connectors. Part-editing mode changes the definition itself. Editing a shared definition must clearly identify the affected references and require an explicit revision update for existing assemblies.

Pressure preview is a bounded mode attached to the current construction document. It must be clearly distinguishable from editing the pristine design and reset without modifying that design unless the user explicitly applies an edit.

The application should be usable with ordinary mouse and keyboard controls, with shortcuts and clear selection behavior. Elaborate animation tooling, general flight simulation, and integrated conversational UI are not initial requirements.

## 14. Storage, export, and migration

### Editable projects

Preserve source images, aligned artwork, physical maps, object definitions, assembly references, and import settings. Save atomically and provide recovery for interrupted work. Session undo and saved project recovery are separate mechanisms.

**Proposed representation:** readable versioned JSON metadata plus PNG artwork and lossless integer map data. The exact schema and map encoding should be settled during the first proof of integration.

Material maps are data, not ordinary color-managed artwork. If PNG is used as a storage container, read its integer values without filtering, palette conversion, lossy compression, or color-space transformations. Define map resolution, byte ordering, and material-ID interpretation explicitly. In Godot, load such maps with `Image.load_from_file`, never through the texture importer, which may compress or filter them.

### Exported bundles

An export contains a schema version, stable asset IDs, pinned dependencies, artwork, physical maps, component and connector definitions, and applicable compartment or celestial-body data.

**Proposed:** the game loads the bundle format directly through the shared core, rather than through generated Godot resources. Editor documents must not depend on Godot resource UIDs. A build may compile editable masks into runtime arrays and geometry for efficient loading.

Identical source documents and exporter versions should produce equivalent runtime data. Derived caches must be distinguishable from authored data and reproducible from it.

Basic export validation checks required fields, finite numerical values, map dimensions, valid references, material IDs, geometric bounds, and the artwork–physics agreement in section 7.1. This is data integrity checking, not the excluded game-capability matrix.

### Migration

Use the current color tables to generate initial explicit material maps for existing ship assets. Preserve the lander's layer thicknesses and tuned performance during this first conversion.

Convert existing grid modules into authored parts/components without silently changing gameplay. Preserve existing station artwork and port locations while introducing explicit construction and compartment definitions in stages.

Keep migrations versioned. Existing content should continue loading during a planned transition, and conversions must never overwrite original artwork without an explicit output operation.

## 15. Performance and resource reporting

The game targets mobile hardware, so the editor should report physical pixel count, occupied depths, texture dimensions, estimated memory, moving-part count, and compartment/connection count.

These counts are useful diagnostics, not guarantees of frame rate. Numerical budgets should follow measurements on the target device rather than arbitrary limits in this document. For reference, the game ran at 120 fps with no dropped frames on the Galaxy Z Fold 8 with the current lander and station in November 2026.

The runtime may chunk large constructions and rebuild only damaged regions. Chunk boundaries must not change component identity, physical connectivity, or sealing. This is a proposed optimization to evaluate after correctness is established.

## 16. Celestial Bodies workspace

**Agreed direction (revised 2026-11-09):** individual planet, moon, and star authoring, scheduled with the first visual application rather than last. Bodies are already data resources drawn by shaders, so this workspace needs no new game systems and is the cheapest useful part of the application.

This workspace edits procedural definitions and displays the game's rendering. It does not convert celestial bodies into destructible ship-style pixel assemblies.

Planet/moon controls include radius, surface gravity, seed, rotation, six-color surface palette, sea level, ice, clouds, atmosphere parameters, mountain and crater settings, ground strata, prop selections, and existing orbit parameters.

Star controls include radius, surface gravity, temperature, color, light falloff, heat distance, and appropriate appearance parameters currently stored in shaders or scene settings.

Preview the whole body, day/night lighting, and close-up surface with live controls. Reuse the game's `body_view.gd`, `star_view.gd`, shaders, and native terrain source as they are, read-only. Export body definitions and support the same structured CLI and MCP access as other documents.

Some current settings are independent despite the longer-term design's physical generation chain. The editor must reflect current parameter meanings; automatic temperature-to-color, climate generation, or habitable-zone calculations require a separately defined generator.

Full system assembly, galaxy generation, and new body renderers for unsupported phenomena remain future work. Background starfield authoring is optional later scope.

## 17. In-game ship assembly

**Proposed foundation:** all complete ships are blueprints made from reusable parts. This allows an in-game builder to use the same definitions later.

The standalone application creates parts and presets. A player-facing builder would place those parts, connect them, and save blueprints. It would use the same construction calculations and compartment rules while providing a simpler interface appropriate to the game and phone.

The recommended first game implementation is assembly in a station hangar. Inventory, prices, build permissions, repair costs, and the availability of parts are game design decisions, not editor responsibilities.

Rearranging a damaged ship must preserve part instance state. Valid assembly geometry does not imply free repairs, fuel, or atmosphere.

Pixel-by-pixel player construction, in-flight construction, and salvage reattachment are separate extensions. Their future existence should not force the first editor to implement their gameplay.

## 18. Required game work and limits of the editor

Replacing color lookup with explicit material maps is a contained integration change. The larger goals require additional game systems:

- Load explicit physical occupancy independently of appearance alpha, within the rules of section 7.1.
- Preserve stable part and component identities across assembly and damage.
- Generalize thrust directions, application points, and RCS behavior.
- Replace fixed lander-size assumptions where arbitrary assemblies require it.
- Adopt shared structural connections and construction definitions for stations.
- Implement damage-driven pressure-boundary updates and atmosphere state.
- Persist live damage and consumables separately from pristine definitions, once the game saves.
- Add the in-game builder if that feature is approved.

The editor can author these definitions, but writing data does not create unimplemented game behavior. Integration should proceed incrementally with the current lander and station as reference content. Claude does this game-side work, and its pace follows the game's own priorities.

### What the game needs from the editor first

The game's next work is cargo and data gigs picked from the station's terminal, so the editor's earliest useful output is:

1. The generalized importer, run from the CLI, for new concept art: more ship modules (cargo first), more station rooms, and characters.
2. The lander and one station room migrated to the bundle format, proving the game can load it.
3. Live body tuning against the real renderer.

## 19. Delivery sequence and acceptance

### Phase 1 — Core, format, and CLI

Create `core/` with the smallest versioned document and bundle format needed for explicit materials, component identity, and blueprint placement, and `editor/cli.gd` to drive it. Convert the current lander and one station room through the CLI.

Acceptance:

- Existing artwork reconstructs correctly after export/import.
- The lander's dry mass, fuel capacity, and intended performance remain equivalent within documented numerical tolerance.
- A visual recolor does not alter mass or strength.
- An explicit material change alters the relevant physical values.
- Physical existence and exposed damage layers no longer depend solely on exterior artwork alpha, and any divergence is flagged as section 7.1 requires.
- Save/load and round-trip export retain IDs, placements, and definitions.
- The core has its own headless tests in `tests/core/`, and the game's existing tests still pass.
- The Android export still builds and does not contain `editor/`.

These are development checks, not a general simulation workspace in the product.

### Phase 2 — Import and assembly through the CLI and MCP

Generalize the slice tools into `import.*` commands, then add parts, blueprints, assembly, and export, all headless. Wrap the handlers in MCP.

Acceptance:

- Running the importer on the existing station and astronaut sources reproduces the current sprites, within documented differences.
- An LLM can create or modify an asset through bounded commands and inspect the result.
- Concurrent commits through the CLI conflict instead of overwriting.
- Multiple blueprints can reuse a part definition without unintended cross-editing.

### Phase 3 — Visual application

Build the desktop application on the same core: canvas, layers, mask and material painting, touch-ups, components, connectors, assembly, persistence, and export, and the celestial-bodies workspace.

Acceptance:

- A user can prepare an imported ship and create a reusable part without editing game source files by hand.
- UI and CLI edits share revisions and transactions, and the application reloads external commits.
- Bodies tune live against the game's own renderer and export.

### Phase 4 — Compartments and pressure preview

Requires the scale decision in section 21. Add the full compartment authoring UI, explicit sealing surfaces, doors, assembled seal checks, and the shared atmosphere preview.

Acceptance:

- A sealed room has no unintended path to space in its specified configuration.
- An exterior surface breach can vent a room even with an intact perimeter.
- Decorative skin loss does not leak when a sealing barrier remains intact.
- Open connections transmit gas loss and closed intact boundaries isolate it.
- Internal transfers conserve gas and all gas quantities remain nonnegative.
- A single room venting to space matches the closed-form exponential decay within tolerance.
- Repair closes a leak without spontaneously replenishing gas.
- Room-to-room joins behave the same in isolated part previews and assembled assets.

The agreed initial constructed-object release includes this focused pressure capability. Game atmosphere and station-damage integration remain separately scheduled work using the shared implementation.

### Separate game milestone — Player-built ships

Build the hangar interface and game-side state handling on the established part and blueprint model. This is not a prerequisite for shipping the standalone editor.

## 20. Collaboration

**Agreed (2026-11-09):** GPT builds the editor; Claude builds the game. Both work in the one repository.

| Area | Owner | Others may |
| --- | --- | --- |
| `editor/`, `tests/core/` | GPT | Read |
| `core/` | GPT, with Claude reviewing anything the game uses | Propose changes through the owner |
| The game's folders: `scripts/`, `scenes/`, `data/`, `shaders/`, `native/`, `art/`, `tests/` | Claude | Read and reuse, not edit |
| `project.godot`, `export_presets.cfg` | Shared | Add only the editor's feature overrides and export preset |
| `docs/ASSET_EDITOR_DESIGN.md` | Shared | Edit, with a change-log row |
| `docs/DESIGN.md` | Claude, for game rules | Request changes through Manny |

- GPT works on its own branch, `asset-editor`, in its own git worktree, so the two never share a working copy. Manny merges.
- Changes to `core/` keep the game's tests passing, and land with tests of their own.
- Anything one side needs from the other goes in the requests table below, or through Manny.
- Both follow `CLAUDE.md`'s conventions: GDScript style, header comments naming the design section, small commits with clear messages, and a `docs/LEARNING_LOG.md` entry per ticket, prefixed "Asset editor:" for editor work.

### Requests between the editor and the game

| Date | From | Request | Status |
| --- | --- | --- | --- |
| 2026-11-09 | Game | The importer as CLI commands first, for new ship modules and station rooms | Open |
| 2026-11-09 | Game | Bundle loading through `core/` with no editor or UI dependencies, so the phone build can use it | Open |

## 21. Open decisions before implementation

1. **Scale.** Settle what one art pixel and one world unit mean, so volumes, masses, and readouts agree. Options: keep one world unit as one meter and treat the pilot as stylized; or keep the pilot to scale at about 5 cm per pixel and change what the HUD reports. This blocks Phase 4 and belongs in `docs/DESIGN.md`. Manny decides.
2. Confirm whether in-game ship assembly is now a committed gameplay feature or only a future requirement for the asset format.
3. Choose compartment volume conventions and effective breach-area rules, once scale is set.
4. Confirm the isothermal first approximation and the treatment of gas mass in gameplay.
5. Define structural joint failure behavior and the relationship between layers, connectivity, and pressure barriers.
6. Settle the version-one serialization schema and integer-map encoding during Phase 1.
7. Decide which part types support mirroring and per-orientation artwork, and which visual-only overlays are permitted.
8. Correct "26 colors" to 25 in `docs/DESIGN.md` and `CLAUDE.md`, recommended, keeping the colors as they are.
9. Decide how a blueprint may combine parts drawn at different pixel scales, such as station rooms at two world units per pixel and ships at one.

These decisions should be resolved when they become dependencies of implementation. They do not require building the excluded systems.

## 22. Source references

Paths below are relative to the repository root:

- `CLAUDE.md` — project rules and conventions for everyone working in the repository.
- `docs/DESIGN.md` — game pillars, modular construction, art direction, pressure intent, and universe generation.
- `scripts/ship/ship_design.gd`, `module_data.gd`, `material_data.gd` — current ship data definitions.
- `scripts/ship/ship_body.gd`, `scripts/ship.gd` — assembly, mass, damage, fuel, and propulsion.
- `scripts/station/station_design.gd`, `station_room.gd`, `station_layout.gd`, `station_view.gd` — current station assembly, collision, docking, and interiors.
- `data/lander_design.tres`, `data/station_1.tres`, `data/materials/`, `data/agency_palette.tres` — reference constructed assets and the palette.
- `tools/slice_lander.gd`, `slice_station.gd`, `slice_pilot.gd`, `make_hud_font.gd` — existing conversion workflows.
- `scripts/body_data.gd`, `scripts/star_data.gd`, `scripts/main.gd` — celestial definitions and current system setup.
- `scripts/body_view.gd`, `scripts/star_view.gd`, `shaders/planet.gdshader`, `shaders/star.gdshader`, `native/src/terrain_profile.cpp` — body rendering and terrain.
- `tests/` — the game's headless tests.

Atmosphere-model background: [NASA Glenn — Mass Flow Rate Equations](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/mass-flow-rate-equations/). A leaking compartment requires a time-dependent gas-inventory model around the opening-flow calculation; the reference alone is not a complete cabin depressurization simulator.

## Change log

| Date | Change |
| --- | --- |
| 2026-11-09 | Revised after Claude's review and Manny's approval: one Godot project with `editor/` and `core/` folders instead of a separate project; Aseprite stays the drawing tool; artwork and physics agree by default, with explicit flags and export errors for differences; the CLI first, with file revisions for concurrency and MCP wrapping it; a simple isothermal flow model; the scale contradiction made the first open decision; the celestial workspace moved into the first visual release; GPT builds the editor and Claude the game, with ownership and requests in section 20. Moved to `docs/` |
| 2026-11-08 | Initial design captures standalone Godot application, explicit physical/material layers, reusable parts and blueprints, pressure/sealing authoring, LLM access, exclusions, celestial-body workspace, and the proposed foundation for player-built ships. |
