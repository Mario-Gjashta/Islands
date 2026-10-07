// Shared terrain: turns the per-hex height texture into one smooth, organic
// height field. Included by the sea/land shader and the tree shader so both
// agree on where the ground is.

// One texel per hex (axial q, r offset by grid_radius); R = displayed height.
uniform sampler2D cells : filter_nearest, repeat_disable;
// World units from a hex centre to a corner.
uniform float hex_size = 1.0;
uniform int grid_radius = 18;

// Height layers: 0 seabed, 1 reef, 2 shallows, 3 beach, 4 meadow, 5 hills,
// 6 highland, 7 mountain, 8 summit.
uniform float sea_level = 2.5;
// World units each layer above the sea rises.
uniform float layer_height = 0.42;
// Higher = tighter hexes, lower = softer, blobbier islands.
uniform float blend_falloff = 1.3;
// How far (in hexes) coastlines wander from the hex grid.
uniform float coast_warp = 0.3;
// How sharply high hexes rise to a point above their neighbours.
uniform float peak_sharpness = 0.3;
// Ridged crags and gullies carved into mountain ground, in layers.
uniform float crag_strength = 0.55;

const float SQRT3 = 1.7320508;
// The painting works in "paint units": one hex is 48 of them, whatever its
// world size, so brush and noise scales stay put if the world is rescaled.
const float PAINT_HEX = 48.0;
// Layers above this start to peak and crag.
const float PEAK_BASE = 4.0;

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

float cell_height(vec2 a) {
	ivec2 i = ivec2(a) + ivec2(grid_radius);
	int n = 2 * grid_radius + 1;
	if (i.x < 0 || i.y < 0 || i.x >= n || i.y >= n) {
		return 0.0;
	}
	return texelFetch(cells, i, 0).r;
}

// Height in layers at a point (paint units). A gaussian blend of the two rings
// of hexes around it gives soft contours; on top, every hex above the meadows
// pushes up a pointed peak near its centre, growing faster the higher it is,
// and ridged noise carves crags into mountain ground.
float terrain(vec2 p) {
	vec2 warp = vec2(fbm(p * 0.012), fbm(p * 0.012 + vec2(5.2, 1.3))) - 0.5;
	vec2 q = p + warp * PAINT_HEX * coast_warp * 2.0;
	vec2 centre = axial_round(paint_to_axial(q));
	float sum = 0.0;
	float weight_sum = 0.0;
	float spikes = 0.0;
	for (int dq = -2; dq <= 2; dq++) {
		for (int dr = -2; dr <= 2; dr++) {
			if (abs(dq + dr) > 2) {
				continue;
			}
			vec2 a = centre + vec2(float(dq), float(dr));
			float h = cell_height(a);
			vec2 d = (q - axial_to_paint(a)) / PAINT_HEX;
			float w = exp(-dot(d, d) * blend_falloff);
			sum += w * h;
			weight_sum += w;
			// Peaks sit a little off-centre so ranges don't look gridded.
			vec2 jitter = (vec2(hash(a + 0.31), hash(a + 0.77)) - 0.5) * 0.6;
			float above = max(h - PEAK_BASE, 0.0);
			spikes += pow(above, 1.5) * exp(-length(d - jitter) * 2.6) * (0.7 + 0.6 * hash(a + 0.13));
		}
	}
	float h = sum / weight_sum;
	float mountain = smoothstep(PEAK_BASE + 0.5, PEAK_BASE + 2.5, h);
	float crags = ridged(q * 0.025) - 0.35;
	return h + spikes * peak_sharpness + mountain * crag_strength * crags;
}

// Extra rise per layer, growing with height, so mountains tower over the
// lowlands instead of stacking up in even steps.
uniform float mountain_rise = 0.11;

// The terrain height, baked once per change into a texture (see
// height_bake.gdshader) so meshes and trees can look it up cheaply instead of
// re-running terrain() for every vertex, every frame. Stored as 16 bits split
// over R (high byte) and G (low byte), scaled by HEIGHT_RANGE.
uniform sampler2D height_map : filter_nearest, repeat_disable;
// World size of the square the height map covers, centred on the origin.
uniform float bake_extent = 80.0;
const float HEIGHT_RANGE = 16.0;

float baked_texel(ivec2 i, ivec2 size) {
	vec4 c = texelFetch(height_map, clamp(i, ivec2(0), size - 1), 0);
	return (c.r + c.g / 255.0) * HEIGHT_RANGE;
}

// Bilinear lookup of the baked height (in layers) at a world xz position.
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

// How likely a spot is to hold a tree, from its height above the sea:
// a few on meadows, forest on the hills, thinning to a tree line on the highlands.
float tree_density(float lift) {
	float meadow = smoothstep(1.15, 1.4, lift) * 0.12;
	float forest = smoothstep(1.85, 2.25, lift) * 0.8;
	return (meadow + forest) * (1.0 - smoothstep(3.0, 3.9, lift));
}
