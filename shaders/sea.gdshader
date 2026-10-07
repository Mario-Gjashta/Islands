shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/terrain.gdshaderinc"

// False for the flat far-ocean plane, which never needs relief.
uniform bool displace = true;

// Palette in sRGB, measured from the reference paintings; converted at the end.
uniform vec3 deep_color = vec3(0.21, 0.58, 0.69);
uniform vec3 reef_color = vec3(0.19, 0.65, 0.70);
uniform vec3 shallow_color = vec3(0.22, 0.73, 0.71);
uniform vec3 lagoon_color = vec3(0.40, 0.82, 0.79);
uniform vec3 stroke_color = vec3(0.15, 0.50, 0.63);
uniform vec3 seabed_shadow_color = vec3(0.16, 0.52, 0.60);
uniform vec3 seagrass_color = vec3(0.20, 0.50, 0.46);
uniform vec3 foam_color = vec3(0.80, 0.90, 0.89);
uniform vec3 foam_bright_color = vec3(0.94, 0.98, 0.97);
uniform vec3 wet_sand_color = vec3(0.70, 0.66, 0.56);
uniform vec3 sand_color = vec3(0.80, 0.76, 0.67);
uniform vec3 scrub_color = vec3(0.66, 0.64, 0.42);
uniform vec3 grass_light_color = vec3(0.57, 0.63, 0.37);
uniform vec3 grass_dark_color = vec3(0.33, 0.50, 0.30);
uniform vec3 marsh_color = vec3(0.44, 0.52, 0.34);
uniform vec3 pool_color = vec3(0.33, 0.66, 0.68);
uniform vec3 rock_light_color = vec3(0.84, 0.78, 0.68);
uniform vec3 rock_dark_color = vec3(0.52, 0.50, 0.45);
uniform vec3 alpine_color = vec3(0.64, 0.66, 0.42);
uniform vec3 scree_color = vec3(0.62, 0.60, 0.54);
uniform vec3 summit_color = vec3(0.72, 0.69, 0.62);

varying vec2 paint_pos;
varying vec3 world_pos;

// Water, painted like the references: flat turquoise broken into slowly
// drifting lighter and darker patches, pale foam swirls that stream around
// the coast, and a few white dashes of light. Everything moves slowly, so it
// reads as liquid without ever looking like glass.
vec3 paint_water(vec2 p, float h, float depth, vec3 fields) {
	float t = TIME;
	// Slow domain warp: the whole pattern breathes and drifts.
	vec2 flow = vec2(fbm(p * 0.006 + t * 0.02), fbm(p * 0.006 + vec2(7.1, 2.3) - t * 0.017)) - 0.5;
	vec2 q = p + flow * 40.0;

	// Depth, nudged by broad noise so the shallows form uneven washes.
	float d = clamp(h / sea_level + (fbm(p * 0.008 + 11.0) - 0.5) * 0.3, 0.0, 1.0);
	vec3 water = mix(deep_color, reef_color, smoothstep(0.15, 0.6, d));
	water = mix(water, shallow_color, smoothstep(0.6, 0.92, d));
	water = mix(water, lagoon_color, smoothstep(0.92, 1.0, d) * 0.5);

	// Open water stays flat; only a faint, very broad drift keeps it alive.
	water *= 0.97 + 0.06 * fbm(q * 0.003 + vec2(0.0, t * 0.006));

	// Seabed shapes seen through the shallows, wobbling with the surface.
	vec2 refracted = p + flow * 12.0;
	float bed = fbm(refracted * 0.01 + vec2(3.7, 1.1));
	float bed_shadow = smoothstep(0.55, 0.62, bed) * smoothstep(0.4, 0.7, d) * (1.0 - smoothstep(0.92, 0.99, d));
	water = mix(water, seabed_shadow_color, bed_shadow * 0.5);
	float lagoon = smoothstep(0.3, 0.8, fields.y);
	water = mix(water, lagoon_color, lagoon * 0.4);
	float grass_beds = smoothstep(0.45, 0.6, fbm(refracted * 0.03));
	water = mix(water, seagrass_color, grass_beds * lagoon * smoothstep(0.3, 0.7, fields.x) * 0.5);

	// Foam swirls: pale ribbons streaming around the coast. They follow the
	// coastline (bands of depth) and drift along it over time.
	float swirl_phase = depth * 8.0 - t * 0.3 + fbm(q * 0.015) * 5.0;
	float ribbons = smoothstep(0.6, 0.8, sin(swirl_phase) * 0.5 + 0.5);
	ribbons *= smoothstep(0.52, 0.66, fbm(q * 0.012 + vec2(t * 0.02, 0.0)));
	ribbons *= 1.0 - smoothstep(0.1, 0.6, depth);
	water = mix(water, foam_color, ribbons * 0.55);
	// A thin brighter line right at the shore.
	float edge_noise = vnoise(q * 0.07);
	float shore = 1.0 - smoothstep(0.0, 0.03 + 0.03 * edge_noise, depth);
	water = mix(water, foam_bright_color, shore * 0.9);

	// Sparse white dashes of light, drifting slowly.
	vec2 dash_cell = floor(q / 26.0);
	vec2 dash_pos = fract(q / 26.0) - 0.5;
	float dash = step(0.9, hash(dash_cell)) * (1.0 - smoothstep(0.03, 0.08, length(dash_pos * vec2(0.4, 2.5))));
	dash *= 0.5 + 0.5 * sin(t * 0.8 + hash(dash_cell + 2.0) * 6.28);
	water = mix(water, foam_bright_color, dash * 0.8 * (1.0 - shore));
	return water;
}

// Land from the blended terrain fields (vegetation, wetness, rock) and the
// slope, painted in broad smooth areas: pale sand, sage greens, marsh and
// spring pools, and bluish-grey rock on steep ground.
vec3 paint_land(vec2 p, float lift, vec3 fields, inout vec3 normal, float y, out float rock_amount) {
	float veg = fields.x;
	float wet = fields.y;
	float rockiness = fields.z;
	float flatness = normal.y;
	float broad = fbm(p * 0.015);
	float wobble = (broad - 0.5) * 0.15;

	vec3 sand = mix(wet_sand_color, sand_color, smoothstep(0.0, 0.07, lift));
	sand *= 0.97 + 0.06 * broad;
	vec3 land = sand;

	// Greens: dry scrub, meadow, deep forest floor. A flat field with only a
	// faint broad drift and a fine, low-contrast stipple of blades.
	vec3 grass = mix(scrub_color, grass_light_color, smoothstep(0.22, 0.38, veg + wobble));
	grass = mix(grass, grass_dark_color, smoothstep(0.45, 0.9, veg + wobble));
	grass *= 0.96 + 0.08 * fbm(p * 0.01 + 4.2);
	grass *= 0.97 + 0.05 * hash(floor(p * 0.9));
	// The field ends in a crisp, ragged edge, with loose tufts spilling a
	// little past it onto the sand and a darker rim just inside.
	float edge = (fbm(p * 0.05 + 2.0) - 0.5) * 0.4;
	float cover = veg + edge;
	float grown = smoothstep(0.17, 0.2, cover) * smoothstep(0.03, 0.08, lift);
	vec3 tuft = voronoi(p * 0.22 + 9.0);
	float tufts = (1.0 - smoothstep(0.18, 0.3, tuft.x)) * step(0.45, tuft.z)
		* smoothstep(0.08, 0.17, cover) * (1.0 - grown) * smoothstep(0.03, 0.08, lift);
	float rim = smoothstep(0.2, 0.23, cover) * (1.0 - smoothstep(0.23, 0.29, cover));
	land = mix(land, grass * (1.0 - 0.18 * rim), max(grown, tufts));

	// Wet ground: marsh at sea level, a freshwater pool at a spring.
	float pools = smoothstep(0.55, 0.6, fbm(p * 0.05 + 7.3));
	vec3 marsh = mix(marsh_color, pool_color, pools);
	land = mix(land, marsh, smoothstep(0.3, 0.7, wet) * (1.0 - smoothstep(0.6, 1.0, lift)));
	float pond = smoothstep(0.7, 0.95, wet) * smoothstep(0.6, 1.0, lift)
		* smoothstep(0.35, 0.5, fbm(p * 0.04 + 1.7) + (wet - 0.8));
	land = mix(land, pool_color, pond);

	// Height progression, each band a flat zone with a ragged edge:
	// upland turns to alpine meadow with scree, the peak to bare rock, and
	// the summit pales.
	float band_edge = (fbm(p * 0.04 + 5.0) - 0.5) * 0.5;
	vec3 alpine = alpine_color * (0.95 + 0.1 * fbm(p * 0.01 + 8.0));
	vec3 scree_blobs = voronoi(p * 0.03 + 3.0);
	float scree = step(0.55, scree_blobs.z) * (1.0 - smoothstep(0.3, 0.45, scree_blobs.x));
	alpine = mix(alpine, scree_color, scree);
	float alpine_mask = smoothstep(1.95, 2.05, lift + band_edge) * smoothstep(0.25, 0.4, rockiness + veg * 0.5);
	land = mix(land, alpine, alpine_mask * (1.0 - smoothstep(0.3, 0.6, veg)));

	// Rock: matte, in large soft bands down the face; paler towards the summit.
	vec2 across = normalize(vec2(-normal.z, normal.x) + vec2(1e-4));
	float along = dot(p, across);
	float bands = fbm(vec2(along * 0.035, y * 0.7));
	// Mountain slopes stay grey-brown; only true cliffs (rock terrain facing
	// the sea) show the pale cream faces.
	vec3 rock = mix(rock_dark_color, rock_light_color, smoothstep(0.4, 0.8, bands) * mix(0.35, 1.0, smoothstep(0.5, 0.9, rockiness) * (1.0 - smoothstep(2.0, 2.8, lift))));
	rock = mix(rock, summit_color, smoothstep(3.0, 3.8, lift + band_edge * 0.5));
	float steep = 1.0 - smoothstep(0.6, 0.78, flatness + wobble);
	float rock_mask = max(steep * smoothstep(0.5, 1.2, lift),
		smoothstep(0.5, 0.9, rockiness) * (1.0 - smoothstep(0.72, 0.88, flatness)));
	// Above the alpine band, everything is bare rock.
	rock_mask = max(rock_mask, smoothstep(2.9, 3.0, lift + band_edge));
	// Greenery clinging to ledges lower down.
	float ledges = smoothstep(0.5, 0.65, flatness) * smoothstep(0.45, 0.6, fbm(p * 0.04 + 2.3))
		* (1.0 - smoothstep(2.6, 3.0, lift));
	rock_mask *= 1.0 - ledges * 0.8;
	land = mix(land, rock, rock_mask);
	rock_amount = rock_mask;

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
		// Water is painted in its final colours, untouched by scene lighting,
		// so it matches the reference exactly.
		emission = srgb_to_linear(paint_water(p, h, depth, fields));
		col = vec3(0.0);
	} else {
		float y = surface_y(h);
		if (displace) {
			// Coarse normals only: fine bumps would sparkle under flat light.
			n = baked_normal(world_pos.xz, 0.4 * hex_size);
			ao = 1.0 - 0.3 * baked_cavity(world_pos.xz, 0.6 * hex_size);
		}
		float rock_amount;
		col = paint_land(p, -depth, fields, n, y, rock_amount);
		// Fields and sand shade almost flat, like a painting; only rock keeps
		// its full relief.
		n = normalize(mix(n, vec3(0.0, 1.0, 0.0), 0.7 * (1.0 - rock_amount)));
		ao = mix(1.0, ao, 0.2 + 0.5 * rock_amount);
	}
	ALBEDO = srgb_to_linear(col) * mix(1.0, ao, 0.35);
	AO = ao;
	EMISSION = emission;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
}

// Painterly light: three flat tones (lit, half, shade) with soft edges,
// instead of a smooth gradient that reads as plastic.
void light() {
	// Two flat tones: lit faces and shaded faces, with a soft seam.
	float ndl = dot(NORMAL, LIGHT);
	float lit = 0.45 + 0.55 * smoothstep(0.05, 0.35, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
}
