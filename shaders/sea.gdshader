shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/terrain.gdshaderinc"

// False for the flat far-ocean plane, which never needs relief.
uniform bool displace = true;
// Direction towards the sun (world space), for glints and reflections.
uniform vec3 sun_direction = vec3(-0.6, 0.7, -0.3);

// Palette in sRGB, sampled from the reference paintings; converted at the end.
uniform vec3 deep_color = vec3(0.13, 0.45, 0.64);
uniform vec3 reef_color = vec3(0.11, 0.57, 0.68);
uniform vec3 shallow_color = vec3(0.25, 0.74, 0.73);
uniform vec3 lagoon_color = vec3(0.50, 0.84, 0.78);
uniform vec3 seabed_shadow_color = vec3(0.08, 0.40, 0.48);
uniform vec3 seagrass_color = vec3(0.10, 0.42, 0.32);
uniform vec3 foam_color = vec3(1.0, 1.0, 1.0);
uniform vec3 sky_zenith_color = vec3(0.36, 0.60, 0.86);
uniform vec3 sky_horizon_color = vec3(0.76, 0.87, 0.95);
uniform vec3 wet_sand_color = vec3(0.72, 0.68, 0.57);
uniform vec3 sand_color = vec3(0.86, 0.83, 0.75);
uniform vec3 scrub_color = vec3(0.62, 0.60, 0.38);
uniform vec3 grass_light_color = vec3(0.45, 0.62, 0.28);
uniform vec3 grass_dark_color = vec3(0.20, 0.41, 0.20);
uniform vec3 marsh_color = vec3(0.40, 0.48, 0.28);
uniform vec3 pool_color = vec3(0.30, 0.60, 0.62);
uniform vec3 rock_light_color = vec3(0.70, 0.68, 0.64);
uniform vec3 rock_dark_color = vec3(0.44, 0.45, 0.48);

varying vec2 paint_pos;
varying vec3 world_pos;

// Small wind ripples on the water, as a world-space normal.
vec3 water_normal(vec2 xz, float t) {
	vec2 a = xz * 1.4 + t * vec2(0.25, 0.08);
	vec2 b = xz * 3.1 - t * vec2(0.18, -0.3);
	float e = 0.06;
	float n = vnoise(a) * 0.6 + vnoise(b) * 0.4;
	float nx = vnoise(a + vec2(e * 1.4, 0.0)) * 0.6 + vnoise(b + vec2(e * 3.1, 0.0)) * 0.4;
	float nz = vnoise(a + vec2(0.0, e * 1.4)) * 0.6 + vnoise(b + vec2(0.0, e * 3.1)) * 0.4;
	return normalize(vec3(-(nx - n) / e * 0.045, 1.0, -(nz - n) / e * 0.045));
}

vec3 sky_color(vec3 dir) {
	return mix(sky_horizon_color, sky_zenith_color, smoothstep(0.0, 0.5, dir.y));
}

// Water body colour by depth, before reflections.
vec3 paint_water(vec2 p, float h, float depth, vec3 fields, out float foam) {
	float t = TIME;
	float d = clamp(h / sea_level, 0.0, 1.0); // 0 = deep, 1 = at the surface
	vec3 water = mix(deep_color, reef_color, smoothstep(0.15, 0.55, d));
	water = mix(water, shallow_color, smoothstep(0.5, 0.82, d));
	water = mix(water, lagoon_color, smoothstep(0.84, 0.99, d));
	// Large slow variation so open water isn't a flat fill.
	water *= 0.93 + 0.14 * fbm(p * 0.004 + vec2(t * 0.01, 0.0));

	// Rocks and seagrass showing through the shallows.
	float bed = fbm(p * 0.012 + vec2(3.7, 1.1));
	float bed_shadow = smoothstep(0.56, 0.62, bed) * smoothstep(0.35, 0.65, d) * (1.0 - smoothstep(0.9, 0.98, d));
	water = mix(water, seabed_shadow_color, bed_shadow * 0.5);
	float lagoon = smoothstep(0.3, 0.8, fields.y);
	water = mix(water, lagoon_color, lagoon * 0.35);
	float grass_beds = smoothstep(0.45, 0.6, fbm(p * 0.03 + vec2(sin(t * 0.4) * 0.05, 0.0)));
	water = mix(water, seagrass_color, grass_beds * lagoon * smoothstep(0.3, 0.7, fields.x) * 0.5);

	// Sunlight rippling over the sandy bottom of the shallows.
	float caustic = vnoise(p * 0.05 + vec2(t * 0.30, t * 0.20))
		* vnoise(p * 0.07 - vec2(t * 0.25, -t * 0.10));
	water += vec3(0.85, 1.0, 0.95) * smoothstep(0.30, 0.55, caustic) * smoothstep(0.65, 0.95, d) * 0.12;

	// Foam: a crisp, broken line hugging the coast, plus swells rolling in.
	float edge_noise = vnoise(p * 0.09 + vec2(t * 0.1));
	float shore = 1.0 - smoothstep(0.0, 0.05 + 0.05 * edge_noise, depth);
	float phase = depth * 10.0 + t * 1.3 + fbm(p * 0.03) * 4.0;
	float swell = smoothstep(0.86, 0.95, sin(phase) * 0.5 + 0.5);
	swell *= 1.0 - smoothstep(0.08, 0.45, depth);
	swell *= smoothstep(0.35, 0.65, fbm(p * 0.05 - vec2(t * 0.05)));
	foam = max(shore, swell * 0.8);
	return water;
}

// Land from the blended terrain fields (vegetation, wetness, rock) and the
// slope: white sand, dry scrub, meadow, deep green forest floor, marsh and
// spring pools, and faceted grey rock on steep ground and cliffs.
// `normal` may be tilted for rock facets.
vec3 paint_land(vec2 p, float lift, vec3 fields, inout vec3 normal, float y) {
	float veg = fields.x;
	float wet = fields.y;
	float rockiness = fields.z;
	float flatness = normal.y;
	float grain = fbm(p * 0.08);
	float wobble = (grain - 0.5) * 0.12;

	// Sand with fine grain and wind ripples.
	vec3 sand = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.07, lift));
	sand *= 0.97 + 0.05 * hash(floor(p * 1.5)) + 0.04 * sin(p.x * 0.35 + vnoise(p * 0.1) * 6.0);
	vec3 land = sand;

	// Grass: big light/dark patches, then tufts, then speckles of blades.
	vec3 grass = mix(scrub_color, grass_light_color, smoothstep(0.22, 0.38, veg + wobble));
	grass = mix(grass, grass_dark_color, smoothstep(0.45, 0.9, veg + wobble));
	float patches = fbm(p * 0.02);
	grass *= 0.86 + 0.28 * patches;
	vec3 tufts = voronoi(p * 0.35);
	grass *= 0.92 + 0.16 * tufts.z - 0.1 * (1.0 - smoothstep(0.0, 0.08, tufts.y));
	grass *= 0.95 + 0.1 * hash(floor(p * 2.0));
	// Flowers dotting open meadow.
	vec2 dot_cell = floor(p / 7.0);
	vec2 dot_pos = fract(p / 7.0) - 0.5 - (vec2(hash(dot_cell + 3.1), hash(dot_cell + 7.7)) - 0.5) * 0.6;
	float meadow = smoothstep(0.3, 0.36, veg) * (1.0 - smoothstep(0.45, 0.6, veg));
	float flower = step(0.88, hash(dot_cell)) * (1.0 - smoothstep(0.1, 0.17, length(dot_pos)));
	vec3 petal = mix(vec3(1.0, 0.95, 0.6), vec3(0.98, 0.72, 0.75), hash(dot_cell + 1.3));
	grass = mix(grass, petal, flower * meadow * 0.9);
	float grown = smoothstep(0.1, 0.22, veg + wobble) * smoothstep(0.03, 0.14, lift);
	land = mix(land, grass, grown);

	// Wet ground: marsh at sea level, a freshwater pool at a spring.
	float pools = smoothstep(0.55, 0.6, fbm(p * 0.05 + 7.3));
	vec3 marsh = mix(marsh_color * (0.9 + 0.2 * vnoise(p * 0.3)), pool_color, pools);
	land = mix(land, marsh, smoothstep(0.3, 0.7, wet) * (1.0 - smoothstep(0.6, 1.0, lift)));
	float pond = smoothstep(0.7, 0.95, wet) * smoothstep(0.6, 1.0, lift)
		* smoothstep(0.35, 0.5, fbm(p * 0.04 + 1.7) + (wet - 0.8));
	land = mix(land, pool_color, pond);

	// Rock: large faceted planes (cellular noise stretched down the slope),
	// each a slightly different shade and tilt, split by dark cracks.
	vec2 across = normalize(vec2(-normal.z, normal.x) + vec2(1e-4));
	float along = dot(p, across);
	vec3 facets = voronoi(vec2(along * 0.045, y * 1.6) + grain);
	vec3 rock = mix(rock_dark_color, rock_light_color, 0.35 + 0.5 * facets.z);
	rock *= 0.9 + 0.15 * vnoise(vec2(along * 0.3, y * 6.0));
	rock *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.06, facets.y));
	float steep = 1.0 - smoothstep(0.62, 0.8, flatness + (grain - 0.5) * 0.15);
	float rock_mask = max(steep * smoothstep(0.5, 1.2, lift),
		smoothstep(0.5, 0.9, rockiness) * (1.0 - smoothstep(0.72, 0.88, flatness)));
	// Greenery clinging to ledges.
	float ledges = smoothstep(0.5, 0.65, flatness) * smoothstep(0.45, 0.6, fbm(p * 0.05 + 2.3));
	rock_mask *= 1.0 - ledges * 0.85;
	land = mix(land, rock, rock_mask);
	// Facets tilt the surface a little, so each plane catches light on its own.
	vec3 tilt = vec3(facets.z - 0.5, 0.0, hash(vec2(facets.z, 3.7)) - 0.5) * 0.45;
	normal = normalize(normal + tilt * rock_mask);

	// Damp, darker sand right at the waterline.
	land *= 1.0 - 0.1 * (1.0 - smoothstep(0.0, 0.04, lift));
	return land;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	paint_pos = world_to_paint(world.xz);
	if (displace) {
		float y = surface_y(baked_height(world.xz));
		VERTEX.y += y;
		world.y += y;
		NORMAL = baked_normal(world.xz, 0.08 * hex_size);
	}
	world_pos = world;
}

void fragment() {
	vec2 p = paint_pos;
	vec3 fields;
	float h = terrain_fields(p, fields);
	float depth = sea_level - h;
	vec3 col;
	vec3 n = vec3(0.0, 1.0, 0.0);
	float ao = 1.0;
	vec3 emission = vec3(0.0);
	if (depth > 0.0) {
		float foam;
		vec3 body = paint_water(p, h, depth, fields, foam);
		vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
		// Ripples fade out with distance so they never shimmer into noise.
		float ripple_fade = 1.0 - smoothstep(8.0, 30.0, length(CAMERA_POSITION_WORLD - world_pos));
		n = normalize(mix(vec3(0.0, 1.0, 0.0), water_normal(world_pos.xz, TIME), ripple_fade));
		vec3 r = reflect(-v, n);
		float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(n, v), 0.0), 5.0);
		float glint = pow(max(dot(r, normalize(sun_direction)), 0.0), 400.0) * 8.0
			+ pow(max(dot(r, normalize(sun_direction)), 0.0), 40.0) * 0.25;
		fresnel *= 1.0 - foam;
		glint *= 1.0 - foam;
		col = mix(body, foam_color, foam) * (1.0 - fresnel * 0.7);
		emission = srgb_to_linear(sky_color(r)) * fresnel * 0.6 + vec3(1.0, 0.96, 0.88) * glint;
	} else {
		float y = surface_y(h);
		if (displace) {
			n = baked_normal(world_pos.xz, 0.04 * hex_size);
			ao = 1.0 - 0.6 * baked_cavity(world_pos.xz, 0.35 * hex_size);
		}
		col = paint_land(p, -depth, fields, n, y);
	}
	ALBEDO = srgb_to_linear(col) * mix(1.0, ao, 0.5);
	AO = ao;
	EMISSION = emission;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * wrap_light(NORMAL, LIGHT, 0.35) * ATTENUATION;
}
