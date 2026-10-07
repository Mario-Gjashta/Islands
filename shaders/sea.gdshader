shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/terrain.gdshaderinc"

// False for the flat far-ocean plane, which never needs relief.
uniform bool displace = true;
// Direction towards the sun (world space), for glints and reflections.
uniform vec3 sun_direction = vec3(-0.6, 0.7, -0.3);

// Palette in sRGB, measured from the reference paintings; converted at the end.
uniform vec3 deep_color = vec3(0.13, 0.38, 0.47);
uniform vec3 reef_color = vec3(0.16, 0.45, 0.53);
uniform vec3 shallow_color = vec3(0.22, 0.58, 0.63);
uniform vec3 lagoon_color = vec3(0.45, 0.72, 0.72);
uniform vec3 stroke_color = vec3(0.09, 0.27, 0.36);
uniform vec3 seabed_shadow_color = vec3(0.12, 0.40, 0.44);
uniform vec3 seagrass_color = vec3(0.18, 0.42, 0.38);
uniform vec3 foam_color = vec3(0.96, 0.98, 0.97);
uniform vec3 sky_zenith_color = vec3(0.44, 0.65, 0.82);
uniform vec3 sky_horizon_color = vec3(0.65, 0.81, 0.89);
uniform vec3 wet_sand_color = vec3(0.78, 0.73, 0.63);
uniform vec3 sand_color = vec3(0.84, 0.82, 0.74);
uniform vec3 scrub_color = vec3(0.62, 0.62, 0.51);
uniform vec3 grass_light_color = vec3(0.44, 0.61, 0.34);
uniform vec3 grass_dark_color = vec3(0.28, 0.44, 0.33);
uniform vec3 marsh_color = vec3(0.42, 0.50, 0.36);
uniform vec3 pool_color = vec3(0.36, 0.60, 0.62);
uniform vec3 rock_light_color = vec3(0.74, 0.77, 0.75);
uniform vec3 rock_dark_color = vec3(0.42, 0.50, 0.56);

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

// Water body colour by depth, before reflections: broad, smooth and matte,
// with long dark brush strokes on open water like the reference paintings.
vec3 paint_water(vec2 p, float h, float depth, vec3 fields, out float foam) {
	float t = TIME;
	// Depth, nudged by broad noise so the shallows form uneven washes
	// around the coast instead of an even ring.
	float d = clamp(h / sea_level + (fbm(p * 0.008 + 11.0) - 0.5) * 0.3, 0.0, 1.0);
	vec3 water = mix(deep_color, reef_color, smoothstep(0.15, 0.6, d));
	water = mix(water, shallow_color, smoothstep(0.6, 0.92, d));
	water = mix(water, lagoon_color, smoothstep(0.92, 1.0, d) * 0.5);

	// Long, soft dark strokes drifting across open water.
	float stroke = fbm(vec2(p.x * 0.003 + t * 0.003, p.y * 0.012));
	float strokes = smoothstep(0.5, 0.62, stroke) * (1.0 - smoothstep(0.35, 0.7, d));
	water = mix(water, stroke_color, strokes * 0.5);
	// Broad slow variation so open water isn't one flat fill.
	water *= 0.94 + 0.12 * fbm(p * 0.004 + vec2(t * 0.01, 0.0));

	// Rocks and seagrass showing through the shallows as soft dark shapes.
	float bed = fbm(p * 0.01 + vec2(3.7, 1.1));
	float bed_shadow = smoothstep(0.55, 0.63, bed) * smoothstep(0.4, 0.7, d) * (1.0 - smoothstep(0.92, 0.99, d));
	water = mix(water, seabed_shadow_color, bed_shadow * 0.45);
	float lagoon = smoothstep(0.3, 0.8, fields.y);
	water = mix(water, lagoon_color, lagoon * 0.4);
	float grass_beds = smoothstep(0.45, 0.6, fbm(p * 0.03));
	water = mix(water, seagrass_color, grass_beds * lagoon * smoothstep(0.3, 0.7, fields.x) * 0.5);

	// Foam: a thin, crisp, broken line at the shore.
	float edge_noise = vnoise(p * 0.07 + vec2(t * 0.08));
	float shore = 1.0 - smoothstep(0.0, 0.035 + 0.03 * edge_noise, depth);
	float phase = depth * 12.0 + t * 1.1 + fbm(p * 0.03) * 4.0;
	float swell = smoothstep(0.9, 0.96, sin(phase) * 0.5 + 0.5);
	swell *= 1.0 - smoothstep(0.06, 0.3, depth);
	swell *= smoothstep(0.45, 0.65, fbm(p * 0.05 - vec2(t * 0.05)));
	foam = max(shore, swell * 0.6);
	// The sea faces the whole sky, so it reads brighter than its pigment.
	return water * 1.3;
}

// Land from the blended terrain fields (vegetation, wetness, rock) and the
// slope, painted in broad smooth areas: pale sand, sage greens, marsh and
// spring pools, and bluish-grey rock on steep ground.
vec3 paint_land(vec2 p, float lift, vec3 fields, inout vec3 normal, float y) {
	float veg = fields.x;
	float wet = fields.y;
	float rockiness = fields.z;
	float flatness = normal.y;
	float broad = fbm(p * 0.015);
	float wobble = (broad - 0.5) * 0.15;

	vec3 sand = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.07, lift));
	sand *= 0.97 + 0.06 * broad;
	vec3 land = sand;

	// Greens: dry scrub, meadow, deep forest floor, varied only in soft patches.
	vec3 grass = mix(scrub_color, grass_light_color, smoothstep(0.22, 0.38, veg + wobble));
	grass = mix(grass, grass_dark_color, smoothstep(0.45, 0.9, veg + wobble));
	grass *= 0.9 + 0.2 * fbm(p * 0.03 + 4.2);
	float grown = smoothstep(0.1, 0.22, veg + wobble) * smoothstep(0.03, 0.14, lift);
	land = mix(land, grass, grown);

	// Wet ground: marsh at sea level, a freshwater pool at a spring.
	float pools = smoothstep(0.55, 0.6, fbm(p * 0.05 + 7.3));
	vec3 marsh = mix(marsh_color, pool_color, pools);
	land = mix(land, marsh, smoothstep(0.3, 0.7, wet) * (1.0 - smoothstep(0.6, 1.0, lift)));
	float pond = smoothstep(0.7, 0.95, wet) * smoothstep(0.6, 1.0, lift)
		* smoothstep(0.35, 0.5, fbm(p * 0.04 + 1.7) + (wet - 0.8));
	land = mix(land, pool_color, pond);

	// Rock: large soft bands running down the face, lit faces pale, the rest
	// cool blue-grey, as in the references.
	vec2 across = normalize(vec2(-normal.z, normal.x) + vec2(1e-4));
	float along = dot(p, across);
	float bands = fbm(vec2(along * 0.03, y * 0.9));
	vec3 rock = mix(rock_dark_color, rock_light_color, smoothstep(0.3, 0.75, bands));
	float steep = 1.0 - smoothstep(0.6, 0.78, flatness + wobble);
	float rock_mask = max(steep * smoothstep(0.5, 1.2, lift),
		smoothstep(0.5, 0.9, rockiness) * (1.0 - smoothstep(0.72, 0.88, flatness)));
	// Greenery clinging to ledges.
	float ledges = smoothstep(0.5, 0.65, flatness) * smoothstep(0.45, 0.6, fbm(p * 0.04 + 2.3));
	rock_mask *= 1.0 - ledges * 0.8;
	land = mix(land, rock, rock_mask);

	// Damp, darker sand right at the waterline.
	land *= 1.0 - 0.05 * (1.0 - smoothstep(0.0, 0.03, lift));
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
		col = mix(body, foam_color, foam) * (1.0 - fresnel * 0.5);
		emission = srgb_to_linear(sky_color(r)) * fresnel * 0.45 + vec3(1.0, 0.96, 0.88) * glint * 0.6;
	} else {
		float y = surface_y(h);
		if (displace) {
			n = baked_normal(world_pos.xz, 0.1 * hex_size);
			ao = 1.0 - 0.35 * baked_cavity(world_pos.xz, 0.5 * hex_size);
		}
		col = paint_land(p, -depth, fields, n, y);
	}
	ALBEDO = srgb_to_linear(col) * mix(1.0, ao, 0.4);
	AO = ao;
	EMISSION = emission;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * wrap_light(NORMAL, LIGHT, 0.5) * ATTENUATION;
}
