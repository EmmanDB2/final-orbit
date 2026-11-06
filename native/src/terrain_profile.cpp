#include "terrain_profile.h"

#include <algorithm>
#include <cmath>

namespace final_orbit {

namespace {

constexpr double FULL_CIRCLE = 6.283185307179586476925286766559;
// How many columns apart the land and sea check is taken. They change slowly, so it's enough.
constexpr int LAND_CHECK_BITS = 5;
// Craters sit in cells this many columns wide, as a power of two.
constexpr int CRATER_CELL_BITS = 12;

uint32_t hash32(uint32_t p_value) {
	const uint32_t state = p_value * 747796405u + 2891336453u;
	const uint32_t word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

double random_at(int64_t p_cell, uint32_t p_seed) {
	return static_cast<double>(hash32(static_cast<uint32_t>(p_cell) * 73856093u ^ p_seed * 83492791u) & 65535u) / 65535.0;
}

double smooth(double p_t) {
	return p_t * p_t * (3.0 - 2.0 * p_t);
}

// The same noise as planet.gdshader, so the rim matches the map seen from orbit.
double corner(int64_t p_x, int64_t p_y, uint32_t p_seed) {
	const uint32_t mixed = static_cast<uint32_t>(p_x) * 73856093u ^ static_cast<uint32_t>(p_y) * 19349663u ^ p_seed * 83492791u;
	return static_cast<double>(hash32(mixed) & 65535u) / 65535.0;
}

double noise_2d(double p_x, double p_y, uint32_t p_seed) {
	const double whole_x = std::floor(p_x);
	const double whole_y = std::floor(p_y);
	const double blend_x = smooth(p_x - whole_x);
	const double blend_y = smooth(p_y - whole_y);
	const int64_t cell_x = static_cast<int64_t>(whole_x);
	const int64_t cell_y = static_cast<int64_t>(whole_y);
	const double bottom = corner(cell_x, cell_y, p_seed) + (corner(cell_x + 1, cell_y, p_seed) - corner(cell_x, cell_y, p_seed)) * blend_x;
	const double top = corner(cell_x, cell_y + 1, p_seed) + (corner(cell_x + 1, cell_y + 1, p_seed) - corner(cell_x, cell_y + 1, p_seed)) * blend_x;
	return bottom + (top - bottom) * blend_y;
}

} // namespace

bool TerrainProfile::is_flat() const {
	return highest() <= 0.0;
}

double TerrainProfile::highest() const {
	return mountain_height + hill_height + rough_height + rock_height + crater_depth * 1.3 + cliff_step;
}

int64_t TerrainProfile::column_count() const {
	return std::max<int64_t>(1, static_cast<int64_t>(std::ceil(FULL_CIRCLE * radius / WORLD_PIXEL)));
}

double TerrainProfile::column_at(double p_along_rim) const {
	return p_along_rim / WORLD_PIXEL;
}

// Value noise around the loop, with bumps 2^bits columns apart. A loop that isn't an exact number
// of bumps gets one slightly shorter bump where it closes, so there's no seam.
double TerrainProfile::noise_1d(int64_t p_column, int p_bits, uint32_t p_salt) const {
	const int64_t columns = column_count();
	const int64_t size = int64_t(1) << p_bits;
	const int64_t cells = std::max<int64_t>(1, (columns + size - 1) >> p_bits);
	const int64_t column = ((p_column % columns) + columns) % columns;
	const int64_t cell = column >> p_bits;
	const int64_t next = (cell + 1) % cells;
	const int64_t cell_start = cell << p_bits;
	const int64_t cell_size = next == 0 ? columns - cell_start : size;
	const double part = static_cast<double>(column - cell_start) / static_cast<double>(cell_size);
	const double a = random_at(cell, seed + p_salt);
	const double b = random_at(next, seed + p_salt);
	return a + (b - a) * smooth(part);
}

double TerrainProfile::ridge_at(double p_column, double p_loop_columns) const {
	if (ridge_height <= 0.0) {
		return 0.0;
	}
	double total = 0.0;
	double weight = 0.66;
	double size = 170.0;
	for (int layer = 0; layer < 3; layer++) {
		const int64_t cells = std::max<int64_t>(1, static_cast<int64_t>(std::round(p_loop_columns / size)));
		const double place = (p_column / p_loop_columns - std::floor(p_column / p_loop_columns)) * static_cast<double>(cells);
		const int64_t cell = static_cast<int64_t>(std::floor(place));
		const double a = random_at(cell % cells, seed + 300u + static_cast<uint32_t>(layer));
		const double b = random_at((cell + 1) % cells, seed + 300u + static_cast<uint32_t>(layer));
		// Folded over at the middle, so it comes to peaks instead of round hills.
		const double value = a + (b - a) * smooth(place - std::floor(place));
		total += (1.0 - std::abs(2.0 * value - 1.0)) * weight;
		weight *= 0.42;
		size *= 0.34;
	}
	return std::floor(total * ridge_height / WORLD_PIXEL) * WORLD_PIXEL;
}

double TerrainProfile::band_at(int64_t p_column) const {
	const int64_t columns = column_count();
	const int64_t column = ((p_column % columns) + columns) % columns;
	const double angle = (static_cast<double>(column) + 0.5) * WORLD_PIXEL / radius;
	double x = std::sin(angle) * radius;
	double y = -std::cos(angle) * radius;
	const double scale = largest_feature * 1.3;
	const double push_x = noise_2d(x / scale, y / scale, seed + 40u) - 0.5;
	const double push_y = noise_2d(x / scale + 5.2, y / scale + 1.3, seed + 41u) - 0.5;
	x += push_x * largest_feature * 0.9;
	y += push_y * largest_feature * 0.9;

	double height = 0.0;
	double weight = 0.5;
	double total = 0.0;
	double feature = largest_feature;
	for (int layer = 0; layer < 4; layer++) {
		height += noise_2d(x / feature, y / feature, seed + static_cast<uint32_t>(layer)) * weight;
		total += weight;
		weight *= 0.52;
		feature *= 0.45;
	}
	height /= total;

	const double level = std::clamp((height - 0.25) * 2.0, 0.0, 0.999);
	if (sea_level <= 0.0) {
		return level * 6.0;
	}
	if (level < sea_level) {
		return level / sea_level * 3.0;
	}
	return 3.0 + (level - sea_level) / (1.0 - sea_level) * 3.0;
}

// How far from the sea a column is: 0 in the sea, rising to 1 a little way inland.
double TerrainProfile::land_share(int64_t p_column) const {
	if (sea_level <= 0.0) {
		return 1.0;
	}
	const int64_t size = int64_t(1) << LAND_CHECK_BITS;
	const int64_t first = p_column & ~(size - 1);
	const double part = static_cast<double>(p_column - first) / static_cast<double>(size);
	const double a = std::clamp((band_at(first) - 3.0) / 0.5, 0.0, 1.0);
	const double b = std::clamp((band_at(first + size) - 3.0) / 0.5, 0.0, 1.0);
	return a + (b - a) * part;
}

double TerrainProfile::crater_change(int64_t p_column) const {
	if (crater_depth <= 0.0) {
		return 0.0;
	}
	const int64_t columns = column_count();
	const int64_t size = int64_t(1) << CRATER_CELL_BITS;
	const int64_t cells = std::max<int64_t>(1, (columns + size - 1) >> CRATER_CELL_BITS);
	const int64_t column = ((p_column % columns) + columns) % columns;
	const int64_t cell = column >> CRATER_CELL_BITS;
	double change = 0.0;
	for (int64_t neighbor = cell - 1; neighbor <= cell + 1; neighbor++) {
		const int64_t wrapped = ((neighbor % cells) + cells) % cells;
		if (random_at(wrapped, seed + 200u) > crater_share) {
			continue;
		}
		const double middle = (static_cast<double>(neighbor) + random_at(wrapped, seed + 201u)) * static_cast<double>(size);
		const double reach = static_cast<double>(size) * (0.15 + 0.35 * random_at(wrapped, seed + 202u));
		const double depth = crater_depth * (0.35 + 0.65 * random_at(wrapped, seed + 203u));
		const double across = std::abs(static_cast<double>(column) - middle) / reach;
		if (across < 1.0) {
			change += depth * (across * across - 1.0) + depth * 0.3 * across * across;
		} else if (across < 1.5) {
			change += depth * 0.3 * (1.5 - across) * 2.0;
		}
	}
	return change;
}

double TerrainProfile::height_at(int64_t p_column, int64_t p_detail_columns) const {
	if (is_flat()) {
		return 0.0;
	}
	double height = crater_depth;
	if (mountain_height > 0.0 && p_detail_columns <= (int64_t(1) << 12)) {
		// Ranges and plains, so there's somewhere flat to land between the peaks.
		const double range = std::clamp((noise_1d(p_column, 15, 100u) - 0.35) * 2.2, 0.0, 1.0);
		const double ridge = 1.0 - std::abs(2.0 * noise_1d(p_column, 13, 101u) - 1.0);
		const double fine_ridge = 1.0 - std::abs(2.0 * noise_1d(p_column, 11, 102u) - 1.0);
		height += mountain_height * range * (ridge * 0.72 + fine_ridge * 0.28);
	}
	if (hill_height > 0.0 && p_detail_columns <= (int64_t(1) << 9)) {
		height += hill_height * (noise_1d(p_column, 10, 103u) * 0.6 + noise_1d(p_column, 8, 104u) * 0.4);
	}
	if (cliff_step > 0.0) {
		// Terraces: most of a step is flat, and it rises all at once at the end.
		const double steps = height / cliff_step;
		const double whole = std::floor(steps);
		const double part = steps - whole;
		height = (whole + part * part * part * part) * cliff_step;
	}
	if (rough_height > 0.0 && p_detail_columns <= (int64_t(1) << 5)) {
		height += rough_height * (noise_1d(p_column, 6, 105u) * 0.65 + noise_1d(p_column, 4, 106u) * 0.35);
	}
	if (rock_height > 0.0 && p_detail_columns <= (int64_t(1) << 1)) {
		height += rock_height * (noise_1d(p_column, 2, 107u) * 0.6 + noise_1d(p_column, 1, 108u) * 0.4);
	}
	height += crater_change(p_column);
	height = std::max(height, 0.0) * land_share(p_column);

	// Whole steps of the pixel size asked for.
	const double row = WORLD_PIXEL * static_cast<double>(p_detail_columns);
	return std::floor(height / row) * row;
}

} // namespace final_orbit
