# 3D pilot model: prompt for Claude Fable 5.2

Attach two images from this folder: `pilot_side_sheet.png` (the astronaut from the side, the look to match) and `pilot_eva_sheet.webp` (the same astronaut from above). Then paste the prompt below.

Save the file it sends back as `scripts/pilot/astronaut_model.gd` in the game project. Claude Code takes it from there: the pixel renderer, the palette and outline shader, and the animation.

---

You're building the player character's 3D model for Final Orbit, a 2D pixel-art space game made in Godot 4.7 with GDScript. It runs on a phone (Galaxy Z Fold, Godot's Compatibility renderer).

The pilot is an astronaut. The game draws them by rendering a 3D model live into a tiny canvas, with no smoothing, so on screen the whole astronaut is about 37 pixels tall (1 pixel = 5 cm). A shader then snaps every pixel to the game's fixed palette and adds a 1-pixel dark outline. So the silhouette and the big blocks of color are what matter. Anything thinner than about 5 cm disappears, and fine detail turns to noise.

The same model is seen from the side when walking on planets, from above inside space stations, and at any angle when tumbling through space on a jetpack. It has to read well from all of those. The side view matters most.

The two attached images are the character to match. The first is the side view, which is the main reference for shape and proportions. The second is the same astronaut from above. Match the look, not the drawings' small details.

## What to build

One GDScript file, `astronaut_model.gd`, with `class_name AstronautModel` extending `Node3D`. When it enters the tree, it builds the whole astronaut in code from Godot's built-in meshes (`BoxMesh`, `SphereMesh`, `CapsuleMesh`, `CylinderMesh`, `PrismMesh`, or an `ArrayMesh` you build where a shape needs it). No `.tscn`, `.glb`, textures, shaders, or add-ons. Don't add cameras, lights, or animation; the game handles those. How you build the shapes within these limits is your call.

The body is rigid pieces on a joint hierarchy, like a suit of armor, with no skinning. Each joint is a `Node3D` at the real joint position, and each piece is a `MeshInstance3D` under the joint it moves with. The game animates the pilot by rotating joints in code, so walking, reaching, jumping, and tumbling have to look right with no gaps opening at shoulders, elbows, wrists, hips, knees, or ankles. Rounded joint rings or overlapping ends do this well.

Use these joint names exactly, since the game finds them by name:

- `root` at ground level between the boot soles, then `pelvis`, `spine`, `chest`, `neck`, `head`.
- `backpack` under `chest`.
- `shoulder_l`, `elbow_l`, `wrist_l` under `chest`, and the same with `_r`.
- `hip_l`, `knee_l`, `ankle_l` under `pelvis`, and the same with `_r`.

Add `Marker3D` nodes for points the game attaches things to:

- `visor`: the middle of the visor's front surface.
- `jet_nozzle_l`, `jet_nozzle_r`: the outlets at the bottom of the backpack, with -Y pointing out of the nozzle.
- `hand_l`, `hand_r`: the middle of each glove's palm.
- `sole_l`, `sole_r`: the middle of the bottom of each boot.

Axes follow Godot's convention: +Y is up, the astronaut faces -Z, and their right hand is on +X. Units are meters. In the rest pose every joint's rotation is zero, and the astronaut stands straight, with arms hanging a little away from the body and feet slightly apart.

Add two small public helpers: `joint(joint_name: StringName) -> Node3D` and `marker(marker_name: StringName) -> Marker3D`.

## Size and proportions

The astronaut is 1.85 m from boot sole to helmet top, with chunky, friendly proportions like the side reference. Approximate sizes, read off the side sprite:

- Helmet: big and round, about 0.6 m tall and 0.62 m across, so roughly a third of the height. Its top is at 1.85 m.
- Visor: on the front of the helmet, about 0.35 m tall and 0.4 m wide, wrapping a little around the sides, centered about 1.45 m up.
- Backpack: a tall box about 1.0 m tall, 0.6 m wide, and 0.35 m deep, from about 0.6 m to 1.6 m up. Its top rises behind the helmet.
- Torso: from the hips at about 0.65 m up to the shoulders at about 1.2 m, about 0.75 m wide across the shoulders.
- Arms: thick, with the gloves hanging at about 0.7 m.
- Legs: short and thick, with the knees at about 0.35 m.
- Boots: about 0.25 m tall and 0.35 m long, with thick soles.

At 5 cm per pixel these sizes give the same silhouette as the sprite, so keep them close.

## Look

Flat colors only: one `StandardMaterial3D` per color, shared between pieces, with an albedo color, no texture, metallic 0, roughness 1, and specular 0. The lighting is turned into 2 or 3 bands of the palette later, so it should only show the form.

Take the colors from `@export var palette: AgencyPalette`. That's the game's Resource with these `Color` properties. Fall back to these hex values when it's null:

| Property | Hex | Use |
| --- | --- | --- |
| `hull_lightest` | E8E4DA | Suit, helmet shell, backpack |
| `hull_lighter` | A9ADB3 | Suit panels and seams, backpack panels |
| `hull_light` | 6B7079 | Darker suit details |
| `hull_mid` | 3D4148 | Joint rings, gloves |
| `hull_dark` | 23262B | Boots, nozzles |
| `gold` | D4A23A | Visor |
| `gold_light` | F2D27A | A highlight shape on the visor |
| `gold_dark` | 9C6B1E | Visor rim |
| `agency_orange` | D9541E | Patch on the left upper arm |
| `agency_blue` | 2F5D8C | Patch on the right upper arm |

Don't use `hull_darkest` (0E0F12): it's reserved for the outline.

Features to include:

- A round helmet with a large gold visor on the front, and a rim around the visor.
- An off-white suit with darker rings at the shoulders, elbows, wrists, hips, knees, and ankles.
- Dark gray gloves, and dark boots with thick soles.
- A boxy life-support backpack with a few raised gray panels and two small nozzles at its bottom.
- A light gray control box on the chest.
- The orange and blue upper-arm patches.

Keep it low-poly: under 2,000 triangles in all, with 8 to 12 segments around spheres and capsules. At this size the silhouette carries everything, so spend detail on the outline shape, not on surface bumps.

## Code

Typed GDScript following the official Godot style guide, starting with a short header comment saying what the file is. Note that it comes from DESIGN.md, "Player". Then add a comment table of every joint's rest position in meters, so the animation code can be checked against it. The model must build the same way every time.

Before you answer, check that:

- Every joint and marker exists with its exact name, in the right parent.
- The heights add up to 1.85 m, with the boot soles at y = 0.
- No pieces poke through each other at rest.
- Nothing important is thinner than 5 cm.

Reply with the complete file, ready to save. After it, add a short note listing anything you assumed or couldn't match.
