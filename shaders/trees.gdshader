shader_type spatial;
render_mode specular_disabled, cull_back;

// Tree canopies are scattered over every hex as candidates; each one reads
// the terrain under it and decides whether it grows, so woods spread and
// recede on their own as land rises and sinks.
#include "res://shaders/terrain.gdshaderinc"

uniform vec3 leaf_light_color = vec3(0.46, 0.64, 0.27);
uniform vec3 leaf_dark_color = vec3(0.15, 0.33, 0.16);
uniform vec3 trunk_color = vec3(0.40, 0.30, 0.22);

varying float tint;
varying float canopy_height;
varying float foliage;
varying vec3 local_pos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 p = world_to_paint(origin.xz);
	float h = baked_height(origin.xz);
	float flatness = baked_normal(origin.xz, 0.15 * hex_size).y;
	float chance = hash(origin.xz * 3.17 + 0.5);
	// Only on land; patchy groves rather than an even carpet.
	float density = tree_density(baked_vegetation(origin.xz), flatness)
		* step(sea_level + 0.3, h) * (0.6 + 0.8 * fbm(p * 0.008));
	float grow = smoothstep(chance, chance + 0.12, density);
	float size = (0.6 + 0.6 * hash(origin.xz * 7.3)) * grow;
	local_pos = VERTEX;
	VERTEX *= size;
	VERTEX.y += surface_y(h) - 0.04;
	tint = hash(origin.xz * 1.9);
	foliage = COLOR.r;
	canopy_height = COLOR.g;
}

void fragment() {
	// Leaf clumps: cellular noise over the canopy breaks it into lit bunches
	// with darker gaps.
	vec3 clumps = voronoi(local_pos.xz * 18.0 + local_pos.y * 9.0 + tint * 13.0);
	vec3 leaf = mix(leaf_dark_color, leaf_light_color, 0.25 + 0.6 * canopy_height + 0.2 * (tint - 0.5));
	leaf *= 0.85 + 0.25 * clumps.z;
	leaf *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.12, clumps.y));
	vec3 col = mix(trunk_color, leaf, foliage);
	ALBEDO = srgb_to_linear(col);
	// Underside of the canopy sits in its own shade.
	AO = mix(0.55, 1.0, canopy_height);
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * wrap_light(NORMAL, LIGHT, 0.6) * ATTENUATION;
}
