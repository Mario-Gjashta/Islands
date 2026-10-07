// Shared terrain: turns the per-hex height texture into one smooth, organic
// height field. Included by the sea/land shader and the tree shader so both
// agree on where the ground is.

// One texel per hex (axial q, r offset by grid_radius): R = displayed height
// level, G = vegetation, B = wetness, A = rock (the cell's terrain fields).
uniform sampler2D cells : filter_nearest, repeat_disable;
// World units from a hex centre to a corner.
uniform float hex_size = 1.0;
uniform int grid_radius = 18;

// Height levels: 0 deep sea, 1 reef, 2 sandbank, 3 sea level, 4 lowland,
// 5 upland, 6 peak. The waterline sits between sandbank and sea level.
uniform float sea_level = 2.5;
// World units each layer above the sea rises.
uniform float layer_height = 0.45;
// Higher = tighter hexes, lower = softer, blobbier islands.
uniform float blend_falloff = 1.3;
// How far (in hexes) coastlines wander from the hex grid.
uniform float coast_warp = 0.42;
// How sharply high cells rise to a summit; mirrored in sea_renderer.gd.
uniform float peak_sharpness = 0.38;
// Depth (in levels) of the ridges and gullies erosion carves into mountains.
uniform float erosion_strength = 0.55;

const float SQRT3 = 1.7320508;
// The painting works in "paint units": one hex is 48 of them, whatever its
// world size, so brush and noise scales stay put if the world is rescaled.
const float PAINT_HEX = 48.0;
// Cells above this level start to rise into peaks.
const float PEAK_BASE = 3.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return value;
}

// Sharp ridges where noise crosses its midpoint: mountain spines and gullies.
float ridged(vec2 p) {
	float value = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		float r = 1.0 - abs(2.0 * vnoise(p) - 1.0);
		value += amp * r * r;
		p = p * 2.1 + vec2(4.3, 7.1);
		amp *= 0.5;
	}
	return value;
}

vec2 axial_to_paint(vec2 a) {
	return PAINT_HEX * vec2(SQRT3 * a.x + SQRT3 * 0.5 * a.y, 1.5 * a.y);
}

vec2 paint_to_axial(vec2 p) {
	return vec2(SQRT3 / 3.0 * p.x - p.y / 3.0, 2.0 / 3.0 * p.y) / PAINT_HEX;
}

vec2 axial_round(vec2 a) {
	vec3 c = vec3(a.x, a.y, -a.x - a.y);
	vec3 r = round(c);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) {
		r.x = -r.y - r.z;
	} else if (d.y > d.z) {
		r.y = -r.x - r.z;
	}
	return r.xy;
}

// A cell's (height, vegetation, wetness, rock); outside the map is deep sea.
vec4 cell_state(vec2 a) {
	ivec2 i = ivec2(a) + ivec2(grid_radius);
	int n = 2 * grid_radius + 1;
	if (i.x < 0 || i.y < 0 || i.x >= n || i.y >= n) {
		return vec4(0.0);
	}
	return texelFetch(cells, i, 0);
}

// Height in levels at a point (paint units), plus the blended terrain fields
// (vegetation, wetness, rock). A gaussian blend of the two rings of hexes
// around the point gives soft contours. High cells rise to off-centre summits,
// sharper the higher they are, and erosion carves branching ridges and
// gullies into mountain flanks; lowland gets gentle rolling hills.
float terrain_fields(vec2 p, out vec3 fields) {
	// Two scales of warp: broad bends in the coast, and smaller coves and points.
	vec2 warp = vec2(fbm(p * 0.008), fbm(p * 0.008 + vec2(5.2, 1.3))) - 0.5;
	warp += (vec2(fbm(p * 0.025 + 3.1), fbm(p * 0.025 + vec2(8.4, 2.2))) - 0.5) * 0.5;
	vec2 q = p + warp * PAINT_HEX * coast_warp * 2.0;
	vec2 centre = axial_round(paint_to_axial(q));
	float sum = 0.0;
	vec3 field_sum = vec3(0.0);
	float weight_sum = 0.0;
	float peaks = 0.0;
	for (int dq = -2; dq <= 2; dq++) {
		for (int dr = -2; dr <= 2; dr++) {
			if (abs(dq + dr) > 2) {
				continue;
			}
			vec2 a = centre + vec2(float(dq), float(dr));
			vec4 state = cell_state(a);
			float h = state.r;
			vec2 d = (q - axial_to_paint(a)) / PAINT_HEX;
			float w = exp(-dot(d, d) * blend_falloff);
			sum += w * h;
			field_sum += w * state.gba;
			weight_sum += w;
			// Summits sit a little off-centre so ranges don't look gridded.
			vec2 jitter = (vec2(hash(a + 0.31), hash(a + 0.77)) - 0.5) * 0.6;
			float above = max(h - PEAK_BASE, 0.0);
			peaks += pow(above, 1.5) * exp(-length(d - jitter) * 2.4) * (0.75 + 0.5 * hash(a + 0.13));
		}
	}
	float h = sum / weight_sum;
	fields = field_sum / weight_sum;
	float mountain = smoothstep(PEAK_BASE, PEAK_BASE + 1.6, h);
	float gullies = ridged(q * 0.02 + warp * 2.0) - 0.45;
	float rolling = (fbm(q * 0.025) - 0.5) * 0.3 * smoothstep(2.9, 3.8, h);
	return h + peaks * peak_sharpness + mountain * erosion_strength * gullies + rolling;
}

float terrain(vec2 p) {
	vec3 fields;
	return terrain_fields(p, fields);
}

// The terrain height, baked once per change into a texture (see
// height_bake.gdshader) so meshes and trees can look it up cheaply instead of
// re-running terrain() for every vertex, every frame. Height is stored as 16
// bits split over R (high byte) and G (low byte), scaled by HEIGHT_RANGE;
// B holds the blended vegetation, for trees.
uniform sampler2D height_map : filter_nearest, repeat_disable;
// World size of the square the height map covers, centred on the origin.
uniform float bake_extent = 80.0;
const float HEIGHT_RANGE = 16.0;

float baked_texel(ivec2 i, ivec2 size) {
	vec4 c = texelFetch(height_map, clamp(i, ivec2(0), size - 1), 0);
	return (c.r + c.g / 255.0) * HEIGHT_RANGE;
}

float baked_vegetation(vec2 xz) {
	ivec2 size = textureSize(height_map, 0);
	ivec2 i = ivec2((xz / bake_extent + 0.5) * vec2(size));
	return texelFetch(height_map, clamp(i, ivec2(0), size - 1), 0).b;
}

// Bilinear lookup of the baked height (in levels) at a world xz position.
float baked_height(vec2 xz) {
	ivec2 size = textureSize(height_map, 0);
	vec2 t = (xz / bake_extent + 0.5) * vec2(size) - 0.5;
	vec2 f = fract(t);
	ivec2 i = ivec2(floor(t));
	float a = baked_texel(i, size);
	float b = baked_texel(i + ivec2(1, 0), size);
	float c = baked_texel(i + ivec2(0, 1), size);
	float d = baked_texel(i + ivec2(1, 1), size);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Extra rise per layer, growing with height, so towers soar over the
// lowlands instead of stacking up in even steps.
uniform float mountain_rise = 0.08;

// Water is a flat surface at y = 0; land rises above it, steeper the higher
// it goes.
float surface_y(float h) {
	float lift = max(h - sea_level, 0.0);
	return lift * layer_height + pow(max(lift - 1.5, 0.0), 1.7) * mountain_rise;
}

vec2 world_to_paint(vec2 xz) {
	return xz * PAINT_HEX / hex_size;
}

vec3 srgb_to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

// Surface normal of the baked terrain at a world xz position; `e` is the
// sampling step in world units.
vec3 baked_normal(vec2 xz, float e) {
	float y = surface_y(baked_height(xz));
	float yx = surface_y(baked_height(xz + vec2(e, 0.0)));
	float yz = surface_y(baked_height(xz + vec2(0.0, e)));
	return normalize(vec3(-(yx - y) / e, 1.0, -(yz - y) / e));
}

// Crevices and valleys: how far the ground sits below its surroundings, 0..1.
float baked_cavity(vec2 xz, float r) {
	float h = baked_height(xz);
	float around = (baked_height(xz + vec2(r, 0.0)) + baked_height(xz - vec2(r, 0.0))
		+ baked_height(xz + vec2(0.0, r)) + baked_height(xz - vec2(0.0, r))) * 0.25;
	return clamp((around - h) * 1.6, 0.0, 1.0);
}

// Cellular noise: x = distance to the nearest feature, y = gap to the second
// nearest (small along cell borders), z = a random id for the nearest cell.
vec3 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(i + g + 5.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

// Soft, painterly sunlight: light wraps a little past the terminator and
// rolls off gently, so forms read round instead of hard-edged.
float wrap_light(vec3 normal, vec3 light_dir, float wrap) {
	float ndl = dot(normal, light_dir);
	return smoothstep(0.0, 1.0, clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0));
}

// How likely a spot is to hold a tree, from the terrain's vegetation
// (forest 1, meadow ~0.4, scrub ~0.2) and how flat it is (1 = level).
float tree_density(float vegetation, float flatness) {
	return smoothstep(0.12, 1.0, vegetation) * 0.85 * smoothstep(0.7, 0.88, flatness);
}
