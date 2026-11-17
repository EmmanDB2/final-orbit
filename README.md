<p align="center"><img src="art/final_orbit_icon.png" width="120" alt="Final Orbit icon"></p>

# Final Orbit

A 2D pixel-art space sandbox for foldable Android phones, built in Godot. You fly cargo and data jobs for a space agency through a star system with real orbital mechanics, in ships that are built from pixels and physically break apart.

**Status:** in active development (Tier 1 of the [design plan](docs/DESIGN.md)).

## Highlights

- **Real orbital mechanics.** Gravity, orbits and momentum run on a custom physics core written in C++. It uses patched conics today, behind an interface built so full n-body physics can replace it later.
- **Ships made of pixels.** Every part has mass, and losing pixels in a crash changes how the ship flies.
- **Made for the Galaxy Z Fold.** The game moves between the folded and unfolded screens without restarting or losing progress.
- **Landing prediction, atmospheric entry and a space station** to fly between.
- **Automated tests** for gravity, landing prediction, aerodynamics, the station and the job system.

## Built with

Godot 4.7 · GDScript · C++ (GDExtension) · shaders

## Run it

1. Build the physics core once (see [native/README.md](native/README.md)).
2. Open `project.godot` in Godot 4.7 and press Play.

The full design, including what's planned for later tiers, is in [docs/DESIGN.md](docs/DESIGN.md).
