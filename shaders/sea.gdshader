shader_type canvas_item;
render_mode unshaded;

// One texel per hex (axial q, r offset by grid_radius); R = displayed height.
uniform sampler2D cells : filter_nearest, repeat_disable;
uniform float hex_size = 48.0;
uniform int grid_radius = 22;

// Height layers: 0 seabed, 1 reef, 2 shallows, 3 beach, 4 land, 5 peak.
uniform float sea_level = 2.5;
// Higher = tighter hexes, lower = softer, blobbier islands.
uniform float blend_falloff = 1.3;
// How far (in hexes) coastlines wander from the hex grid.
uniform float coast_warp = 0.3;

uniform vec3 deep_color : source_color = vec3(0.10, 0.20, 0.34);
uniform vec3 reef_color : source_color = vec3(0.15, 0.40, 0.52);
uniform vec3 shallow_color : source_color = vec3(0.33, 0.66, 0.68);
uniform vec3 lagoon_color : source_color = vec3(0.64, 0.86, 0.80);
uniform vec3 foam_color : source_color = vec3(0.97, 0.97, 0.93);
uniform vec3 wet_sand_color : source_color = vec3(0.72, 0.64, 0.49);
uniform vec3 sand_color : source_color = vec3(0.91, 0.84, 0.67);
uniform vec3 grass_color : source_color = vec3(0.65, 0.70, 0.46);
uniform vec3 stone_color : source_color = vec3(0.75, 0.71, 0.63);

const float SQRT3 = 1.7320508;

varying vec2 world_pos;

void vertex() {
	// The renderer node sits at the origin, so local space is world space.
	world_pos = VERTEX;
}

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

vec2 axial_to_world(vec2 a) {
	return hex_size * vec2(SQRT3 * a.x + SQRT3 * 0.5 * a.y, 1.5 * a.y);
}

vec2 world_to_axial(vec2 p) {
	return vec2(SQRT3 / 3.0 * p.x - p.y / 3.0, 2.0 / 3.0 * p.y) / hex_size;
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

// Smooth height field: gaussian-weighted blend of the two rings of hexes
// around the point, so hex rules underneath become soft contours on top.
float blended_height(vec2 p) {
	vec2 centre = axial_round(world_to_axial(p));
	float sum = 0.0;
	float weight_sum = 0.0;
	for (int dq = -2; dq <= 2; dq++) {
		for (int dr = -2; dr <= 2; dr++) {
			if (abs(dq + dr) > 2) {
				continue;
			}
			vec2 a = centre + vec2(float(dq), float(dr));
			vec2 d = (p - axial_to_world(a)) / hex_size;
			float w = exp(-dot(d, d) * blend_falloff);
			sum += w * cell_height(a);
			weight_sum += w;
		}
	}
	return sum / weight_sum;
}

float terrain(vec2 p) {
	vec2 warp = vec2(fbm(p * 0.012), fbm(p * 0.012 + vec2(5.2, 1.3))) - 0.5;
	return blended_height(p + warp * hex_size * coast_warp * 2.0);
}

vec3 paint_water(vec2 p, float h, float depth, float grain) {
	float d = clamp(h / sea_level, 0.0, 1.0); // 0 = deep, 1 = at the surface
	vec3 water = mix(deep_color, reef_color, smoothstep(0.05, 0.45, d));
	water = mix(water, shallow_color, smoothstep(0.42, 0.78, d));
	water = mix(water, lagoon_color, smoothstep(0.78, 0.98, d));
	float t = TIME;
	water *= 0.92 + 0.14 * grain;
	// Broad, slow brush washes so open water never reads as flat.
	water *= 0.9 + 0.2 * fbm(p * 0.004 + vec2(t * 0.01, 0.0));

	// Seabed light through the shallows.
	float caustic = vnoise(p * 0.05 + vec2(t * 0.30, t * 0.20))
		* vnoise(p * 0.07 - vec2(t * 0.25, -t * 0.10));
	water += vec3(0.9, 0.95, 0.8) * smoothstep(0.30, 0.55, caustic) * smoothstep(0.5, 0.95, d) * 0.12;

	// Foam: a broken white line hugging the coast, plus soft swells rolling in.
	float edge_noise = vnoise(p * 0.09 + vec2(t * 0.1));
	float shore = 1.0 - smoothstep(0.0, 0.08 + 0.06 * edge_noise, depth);
	float phase = depth * 10.0 + t * 1.3 + fbm(p * 0.03) * 4.0;
	float swell = smoothstep(0.80, 0.97, sin(phase) * 0.5 + 0.5);
	swell *= 1.0 - smoothstep(0.08, 0.6, depth);
	swell *= smoothstep(0.35, 0.65, fbm(p * 0.05 - vec2(t * 0.05)));
	float foam = max(shore, swell * 0.75);
	vec3 col = mix(water, foam_color, foam);

	// Sun sparkles: sparse glints that blink in and out on open water.
	vec2 glint_cell = floor(p / 22.0);
	vec2 glint_pos = fract(p / 22.0) - 0.5;
	float seed = hash(glint_cell);
	float blink = pow(max(0.0, sin(t * (1.5 + seed * 2.0) + seed * 40.0)), 24.0);
	float glint = step(0.8, hash(glint_cell + 4.1)) * blink
		* (1.0 - smoothstep(0.02, 0.1, length(glint_pos * vec2(0.6, 1.6))));
	col += vec3(1.0) * glint * 0.6 * (1.0 - foam);
	return col;
}

vec3 paint_land(vec2 p, float lift, vec2 grad, float grain) {
	float wobble = (grain - 0.5) * 0.25;
	// Beach (layer 3) sits 0.5 above the sea, land 1.5, peaks 2.5.
	vec3 land = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.10, lift));
	land = mix(land, grass_color, smoothstep(0.92, 1.08, lift + wobble));

	// Flower dots scattered on the meadow.
	vec2 dot_cell = floor(p / 7.0);
	vec2 dot_pos = fract(p / 7.0) - 0.5 - (vec2(hash(dot_cell + 3.1), hash(dot_cell + 7.7)) - 0.5) * 0.6;
	float meadow = smoothstep(1.15, 1.3, lift) * (1.0 - smoothstep(1.75, 1.9, lift));
	float flower = step(0.9, hash(dot_cell)) * (1.0 - smoothstep(0.12, 0.2, length(dot_pos)));
	vec3 petal = mix(vec3(0.96, 0.92, 0.66), vec3(0.93, 0.74, 0.70), hash(dot_cell + 1.3));
	land = mix(land, petal, flower * meadow * 0.85);

	land = mix(land, stone_color, smoothstep(1.92, 2.08, lift + wobble));

	// Soft hill shading, lit from the top left.
	vec3 normal = normalize(vec3(-grad * 0.7, 1.0));
	float lambert = dot(normal, normalize(vec3(-1.0, -1.0, 1.2)));
	land *= 1.0 + 0.55 * (lambert - 0.647);

	// Darker, wet-pigment edges where layers meet and at the shoreline.
	float layer_edge = 1.0 - smoothstep(0.0, 0.05, abs(lift + wobble - 1.0));
	layer_edge = max(layer_edge, 1.0 - smoothstep(0.0, 0.05, abs(lift + wobble - 2.0)));
	land *= 1.0 - 0.10 * layer_edge;
	land *= 1.0 - 0.15 * (1.0 - smoothstep(0.0, 0.04, lift));
	return land;
}

void fragment() {
	vec2 p = world_pos;
	float h = terrain(p);
	float e = hex_size * 0.1;
	vec2 grad = vec2(terrain(p + vec2(e, 0.0)) - h, terrain(p + vec2(0.0, e)) - h) / e * hex_size;
	float grain = fbm(p * 0.08);

	float depth = sea_level - h;
	vec3 col = depth > 0.0
		? paint_water(p, h, depth, grain)
		: paint_land(p, -depth, grad, grain);

	// Watercolour paper texture over everything.
	col *= 0.95 + 0.07 * vnoise(p * 0.6) - 0.03 * vnoise(p * 0.03);
	COLOR = vec4(col, 1.0);
}
