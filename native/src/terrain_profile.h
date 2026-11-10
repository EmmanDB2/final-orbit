// terrain_profile.h: the seeded height of a body's ground all the way around its rim.
// From DESIGN.md, "Camera, zoom, and landing" (terrain) and "Universe generation" (the same seed
// must give the same world). Physics and drawing both read this, so what you see is what you hit.
//
// The rim is a loop of columns, each one world pixel wide. Heights are whole world pixels above
// the body's base radius, so the ground has the same chunky steps as its art.
#pragma once

#include <cstdint>
#include <vector>

namespace final_orbit {

class TerrainProfile {
public:
	// One column and one row of ground are this many world units across.
	static constexpr double WORLD_PIXEL = 2.0;

	uint32_t seed = 1;
	double radius = 0.0;
	double mountain_height = 0.0;
	double hill_height = 0.0;
	double rough_height = 0.0;
	double rock_height = 0.0;
	double crater_depth = 0.0;
	double crater_share = 0.0;
	double ridge_height = 0.0;
	double cliff_step = 0.0;
	// The look of the surface map, which decides where the sea is. See planet.gdshader.
	double sea_level = 0.0;
	double largest_feature = 1.0;

	bool is_flat() const;
	// How high the ground can ever get above the base radius.
	double highest() const;
	// How many columns go around the rim.
	int64_t column_count() const;
	// The column under a point on the rim, measured along it in world units.
	double column_at(double p_along_rim) const;
	// Ground height above the base radius at a column, in world units. Bumps narrower than
	// p_detail_columns are left out, which is how a far-out view skips detail it can't show.
	double height_at(int64_t p_column, int64_t p_detail_columns = 1) const;
	// The height of a far-off line of mountains behind the skyline, at any point along a loop of
	// p_loop_columns. Moving through it slower than the ground makes it look far away.
	double ridge_at(double p_column, double p_loop_columns) const;
	// Which of the surface map's six colors the rim is at a column, from 0 to just under 6.
	double band_at(int64_t p_column) const;
	// Levels the ground from column p_first to p_last, for a place built on it, at the average
	// height of the ground there, and blends back to the terrain over p_blend columns each side.
	// Returns the level's height above the base radius.
	double add_flat_zone(int64_t p_first, int64_t p_last, int64_t p_blend);

private:
	struct FlatZone {
		int64_t first = 0;
		int64_t last = 0;
		int64_t blend = 0;
		double height = 0.0;
	};
	std::vector<FlatZone> flat_zones;

	// The seeded height, before any level patches.
	double natural_height_at(int64_t p_column, int64_t p_detail_columns) const;
	double noise_1d(int64_t p_column, int p_bits, uint32_t p_salt) const;
	double land_share(int64_t p_column) const;
	double crater_change(int64_t p_column) const;
};

} // namespace final_orbit
