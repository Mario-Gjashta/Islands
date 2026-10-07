shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/terrain.gdshaderinc"

// False for the flat far-ocean plane, which never needs relief.
uniform bool displace = true;

// Palette in sRGB; converted once at the end.
uniform vec3 deep_color = vec3(0.07, 0.30, 0.50);
uniform vec3 deep_stroke_color = vec3(0.05, 0.21, 0.40);
uniform vec3 reef_color = vec3(0.08, 0.48, 0.62);
uniform vec3 shallow_color = vec3(0.20, 0.70, 0.70);
uniform vec3 lagoon_color = vec3(0.52, 0.86, 0.80);
uniform vec3 seabed_shadow_color = vec3(0.04, 0.33, 0.42);
uniform vec3 foam_color = vec3(0.98, 0.99, 0.97);
uniform vec3 wet_sand_color = vec3(0.72, 0.69, 0.60);
uniform vec3 sand_color = vec3(0.88, 0.85, 0.76);
uniform vec3 grass_light_color = vec3(0.44, 0.62, 0.27);
uniform vec3 grass_dark_color = vec3(0.17, 0.38, 0.18);
uniform vec3 rock_light_color = vec3(0.70, 0.69, 0.66);
uniform vec3 rock_dark_color = vec3(0.46, 0.47, 0.49);
uniform vec3 scrub_color = vec3(0.66, 0.63, 0.40);
uniform vec3 marsh_color = vec3(0.36, 0.42, 0.26);
uniform vec3 pool_color = vec3(0.27, 0.52, 0.52);
uniform vec3 seagrass_color = vec3(0.12, 0.40, 0.30);

varying vec2 paint_pos;
varying vec3 world_normal;
// Real height of the surface in world units, for patterns that run down cliffs.
varying float world_y;

vec3 paint_water(vec2 p, float h, float depth, vec3 fields, float grain) {
	float t = TIME;
	float d = clamp(h / sea_level, 0.0, 1.0); // 0 = deep, 1 = at the surface
	vec3 water = mix(deep_color, reef_color, smoothstep(0.1, 0.5, d));
	water = mix(water, shallow_color, smoothstep(0.45, 0.8, d));
	water = mix(water, lagoon_color, smoothstep(0.82, 0.99, d));

	// Long, dark brush strokes drifting across open water.
	float stroke = fbm(vec2(p.x * 0.0025 + t * 0.004, p.y * 0.011) + vec2(0.0, t * 0.01));
	float strokes = smoothstep(0.52, 0.6, stroke) * (1.0 - smoothstep(0.3, 0.6, d));
	water = mix(water, deep_stroke_color, strokes * 0.6);

	// Rocks and seagrass showing through the shallows as dark shapes.
	float bed = fbm(p * 0.012 + vec2(3.7, 1.1));
	float shadows = smoothstep(0.56, 0.62, bed) * smoothstep(0.3, 0.6, d) * (1.0 - smoothstep(0.9, 0.98, d));
	water = mix(water, seabed_shadow_color, shadows * 0.55);
	// Lagoons: calm, bright water over swaying seagrass meadows.
	float lagoon = smoothstep(0.3, 0.8, fields.y);
	water = mix(water, lagoon_color * 1.04, lagoon * 0.45);
	float grass_beds = smoothstep(0.45, 0.6, fbm(p * 0.03 + vec2(sin(t * 0.4) * 0.05, 0.0)));
	water = mix(water, seagrass_color, grass_beds * lagoon * smoothstep(0.3, 0.7, fields.x) * 0.55);
	water *= 0.95 + 0.1 * grain;

	// Sunlight rippling over the sandy bottom of the shallows.
	float caustic = vnoise(p * 0.05 + vec2(t * 0.30, t * 0.20))
		* vnoise(p * 0.07 - vec2(t * 0.25, -t * 0.10));
	water += vec3(0.85, 1.0, 0.95) * smoothstep(0.30, 0.55, caustic) * smoothstep(0.6, 0.95, d) * 0.14;

	// Foam: a broken white line hugging the coast, plus soft swells rolling in.
	float edge_noise = vnoise(p * 0.09 + vec2(t * 0.1));
	float shore = 1.0 - smoothstep(0.0, 0.07 + 0.06 * edge_noise, depth);
	float phase = depth * 10.0 + t * 1.3 + fbm(p * 0.03) * 4.0;
	float swell = smoothstep(0.82, 0.97, sin(phase) * 0.5 + 0.5);
	swell *= 1.0 - smoothstep(0.08, 0.5, depth);
	swell *= smoothstep(0.35, 0.65, fbm(p * 0.05 - vec2(t * 0.05)));
	float foam = max(shore, swell * 0.7);
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

// Land, painted from the blended terrain fields (vegetation, wetness, rock):
// white sand where nothing grows, dry scrub, meadow and deep forest floor as
// vegetation rises, marsh and spring pools where it's wet, and grey granite
// on rock and on any face too steep to hold soil.
vec3 paint_land(vec2 p, float lift, vec3 fields, vec3 normal, float y, float grain) {
	float veg = fields.x;
	float wet = fields.y;
	float rockiness = fields.z;
	float flatness = normal.y;
	float wobble = (grain - 0.5) * 0.12;

	vec3 land = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.08, lift));
	// Sand ripples.
	land *= 0.96 + 0.06 * vnoise(vec2(p.x * 0.3, p.y * 0.08));

	// Vegetation: dry scrub, then meadow, then dark forest floor.
	vec3 grass = mix(scrub_color, grass_light_color, smoothstep(0.22, 0.38, veg + wobble));
	grass = mix(grass, grass_dark_color, smoothstep(0.45, 0.9, veg + wobble));
	grass *= 0.9 + 0.2 * vnoise(p * 0.25);
	// Flowers dotting open meadow.
	vec2 dot_cell = floor(p / 7.0);
	vec2 dot_pos = fract(p / 7.0) - 0.5 - (vec2(hash(dot_cell + 3.1), hash(dot_cell + 7.7)) - 0.5) * 0.6;
	float meadow = smoothstep(0.3, 0.36, veg) * (1.0 - smoothstep(0.45, 0.6, veg));
	float flower = step(0.88, hash(dot_cell)) * (1.0 - smoothstep(0.12, 0.2, length(dot_pos)));
	vec3 petal = mix(vec3(0.98, 0.93, 0.62), vec3(0.95, 0.70, 0.72), hash(dot_cell + 1.3));
	grass = mix(grass, petal, flower * meadow * 0.85);
	// Sand shows through at the very edge of the sea.
	float grown = smoothstep(0.1, 0.22, veg + wobble) * smoothstep(0.02, 0.15, lift);
	land = mix(land, grass, grown);

	// Wet ground: marsh at sea level, a freshwater pool at a spring.
	float pools = smoothstep(0.55, 0.62, fbm(p * 0.05 + 7.3));
	vec3 marsh = mix(marsh_color * (0.9 + 0.2 * vnoise(p * 0.3)), pool_color, pools);
	land = mix(land, marsh, smoothstep(0.3, 0.7, wet) * (1.0 - smoothstep(0.6, 1.0, lift)));
	float pond = smoothstep(0.7, 0.95, wet) * smoothstep(0.6, 1.0, lift)
		* smoothstep(0.35, 0.55, fbm(p * 0.04 + 1.7) + (wet - 0.8));
	land = mix(land, pool_color * 1.1, pond);

	// Granite on rock and steep ground. Streaks run down the face: noise
	// changes fast across the slope and slowly with height.
	vec2 across = normalize(vec2(-normal.z, normal.x) + vec2(1e-4));
	float along = dot(p, across);
	float streak = fbm(vec2(along * 0.05, y * 1.2));
	vec3 rock = mix(rock_dark_color, rock_light_color, smoothstep(0.3, 0.7, streak));
	rock *= 0.92 + 0.12 * vnoise(vec2(along * 0.25, y * 5.0));
	float crack = 1.0 - smoothstep(0.0, 0.025, abs(vnoise(vec2(along * 0.035, y * 0.6) + 9.1) - 0.5));
	rock *= 1.0 - 0.25 * crack;
	rock *= 0.8 + 0.2 * smoothstep(0.3, 2.0, y);
	float steep = 1.0 - smoothstep(0.55, 0.75, flatness + (grain - 0.5) * 0.2);
	float rock_mask = max(steep * smoothstep(0.3, 0.9, lift), smoothstep(0.5, 0.9, rockiness) * (1.0 - smoothstep(0.75, 0.9, flatness)));
	// Moss and creepers on ledges; soil and greenery on flat rock tops.
	float moss = smoothstep(0.55, 0.7, fbm(p * 0.06 + 2.3)) * smoothstep(0.35, 0.55, flatness);
	moss = max(moss, smoothstep(0.45, 0.62, flatness) * smoothstep(1.5, 2.5, lift));
	rock = mix(rock, grass_dark_color * 1.1, moss * 0.85);
	land = mix(land, rock, rock_mask);

	// Damp, darker sand right at the waterline.
	land *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.04, lift));
	return land;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	paint_pos = world_to_paint(world.xz);
	world_normal = vec3(0.0, 1.0, 0.0);
	world_y = 0.0;
	if (displace) {
		world_y = surface_y(baked_height(world.xz));
		VERTEX.y += world_y;
		world_normal = baked_normal(world.xz, 0.08 * hex_size);
		NORMAL = world_normal;
	}
}

void fragment() {
	vec2 p = paint_pos;
	// Colours come from the per-pixel height, so coastlines stay crisp even
	// where the mesh is coarser than the foam line.
	vec3 fields;
	float h = terrain_fields(p, fields);
	float grain = fbm(p * 0.08);
	float depth = sea_level - h;
	vec3 col = depth > 0.0
		? paint_water(p, h, depth, fields, grain)
		: paint_land(p, -depth, fields, normalize(world_normal), world_y, grain);

	// Faint paper texture keeps the painted feel.
	col *= 0.97 + 0.05 * vnoise(p * 0.6);
	ALBEDO = srgb_to_linear(col);
	ROUGHNESS = 1.0;
}
