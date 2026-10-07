shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/terrain.gdshaderinc"

// False for the flat far-ocean plane, which never needs relief.
uniform bool displace = true;

// Palette in sRGB; converted once at the end.
uniform vec3 deep_color = vec3(0.10, 0.20, 0.34);
uniform vec3 reef_color = vec3(0.15, 0.40, 0.52);
uniform vec3 shallow_color = vec3(0.33, 0.66, 0.68);
uniform vec3 lagoon_color = vec3(0.64, 0.86, 0.80);
uniform vec3 foam_color = vec3(0.97, 0.97, 0.93);
uniform vec3 wet_sand_color = vec3(0.72, 0.64, 0.49);
uniform vec3 sand_color = vec3(0.88, 0.81, 0.66);
uniform vec3 grass_color = vec3(0.65, 0.70, 0.46);
uniform vec3 forest_floor_color = vec3(0.50, 0.60, 0.38);
uniform vec3 scree_color = vec3(0.64, 0.62, 0.54);
uniform vec3 rock_dark_color = vec3(0.55, 0.50, 0.46);
uniform vec3 rock_light_color = vec3(0.82, 0.77, 0.68);
uniform vec3 snow_color = vec3(0.95, 0.96, 0.98);

varying vec2 paint_pos;
varying vec3 world_normal;

vec3 paint_water(vec2 p, float h, float depth, float grain) {
	float t = TIME;
	float d = clamp(h / sea_level, 0.0, 1.0); // 0 = deep, 1 = at the surface
	vec3 water = mix(deep_color, reef_color, smoothstep(0.05, 0.45, d));
	water = mix(water, shallow_color, smoothstep(0.42, 0.78, d));
	water = mix(water, lagoon_color, smoothstep(0.78, 0.98, d));
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

// Land by height above the sea (in layers): beach, meadow, forest floor,
// scree, banded rock, snow; steep slopes break out into bare cliffs.
vec3 paint_land(vec2 p, float lift, float flatness, float grain) {
	float wobble = (grain - 0.5) * 0.25;
	vec3 land = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.10, lift));
	land = mix(land, grass_color, smoothstep(0.92, 1.08, lift + wobble));

	// Flower dots scattered on the meadow.
	vec2 dot_cell = floor(p / 7.0);
	vec2 dot_pos = fract(p / 7.0) - 0.5 - (vec2(hash(dot_cell + 3.1), hash(dot_cell + 7.7)) - 0.5) * 0.6;
	float meadow = smoothstep(1.15, 1.3, lift) * (1.0 - smoothstep(1.75, 1.95, lift));
	float flower = step(0.9, hash(dot_cell)) * (1.0 - smoothstep(0.12, 0.2, length(dot_pos)));
	vec3 petal = mix(vec3(0.96, 0.92, 0.66), vec3(0.93, 0.74, 0.70), hash(dot_cell + 1.3));
	land = mix(land, petal, flower * meadow * 0.85);

	// Hills: darker, mossy forest floor.
	land = mix(land, forest_floor_color * (0.9 + 0.2 * fbm(p * 0.05)), smoothstep(1.85, 2.2, lift + wobble));

	// Highlands: grass thins into scree.
	float scree_mask = smoothstep(2.8, 3.4, lift + wobble * 2.0);
	vec3 scree = scree_color * (0.85 + 0.3 * vnoise(p * 0.4));
	land = mix(land, scree, scree_mask);

	// Rock with sedimentary strata: bands follow the height, bent by noise.
	float strata = sin(lift * 9.0 + fbm(p * 0.015) * 5.0) * 0.5 + 0.5;
	vec3 rock = mix(rock_dark_color, rock_light_color, smoothstep(0.2, 0.8, strata));
	rock *= 0.88 + 0.24 * vnoise(p * 0.12);
	float cliff = (1.0 - smoothstep(0.5, 0.72, flatness)) * smoothstep(1.4, 2.0, lift);
	float rock_mask = max(smoothstep(3.6, 4.1, lift + wobble * 2.0), cliff);
	land = mix(land, rock, rock_mask);

	// Snow caps: settles on high ground, slides off the steepest faces.
	float snow_line = 4.9 + (fbm(p * 0.02) - 0.5) * 0.6;
	float snow = smoothstep(snow_line, snow_line + 0.25, lift) * smoothstep(0.35, 0.6, flatness);
	land = mix(land, snow_color, snow);

	// Darker, wet-pigment edge where meadow meets beach, and at the shoreline.
	float layer_edge = 1.0 - smoothstep(0.0, 0.05, abs(lift + wobble - 1.0));
	land *= 1.0 - 0.10 * layer_edge;
	land *= 1.0 - 0.15 * (1.0 - smoothstep(0.0, 0.04, lift));
	return land;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	paint_pos = world_to_paint(world.xz);
	world_normal = vec3(0.0, 1.0, 0.0);
	if (displace) {
		float e = 0.1 * hex_size;
		float y = surface_y(baked_height(world.xz));
		float yx = surface_y(baked_height(world.xz + vec2(e, 0.0)));
		float yz = surface_y(baked_height(world.xz + vec2(0.0, e)));
		VERTEX.y += y;
		world_normal = normalize(vec3(-(yx - y) / e, 1.0, -(yz - y) / e));
		NORMAL = world_normal;
	}
}

void fragment() {
	vec2 p = paint_pos;
	// Colours come from the per-pixel height, so coastlines stay crisp even
	// where the mesh is coarser than the foam line.
	float h = terrain(p);
	float grain = fbm(p * 0.08);
	float depth = sea_level - h;
	vec3 col = depth > 0.0
		? paint_water(p, h, depth, grain)
		: paint_land(p, -depth, normalize(world_normal).y, grain);

	// Watercolour paper texture over everything.
	col *= 0.95 + 0.07 * vnoise(p * 0.6) - 0.03 * vnoise(p * 0.03);
	ALBEDO = srgb_to_linear(col);
	ROUGHNESS = 1.0;
}
