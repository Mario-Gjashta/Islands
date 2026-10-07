shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Painted tree sprites on camera-facing cards. Cards are scattered over every
// hex as candidates; each one reads the terrain under it and decides whether
// it grows, so woods spread and recede on their own as land rises and sinks.
#include "res://shaders/terrain.gdshaderinc"

// 2x2 atlas: three round trees and a conifer (bottom right).
uniform sampler2D atlas : filter_linear_mipmap;
// Height of a full-grown tree card in world units.
uniform float tree_height = 1.1;

varying vec2 atlas_uv;
varying float shade;

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
	float size = tree_height * (0.75 + 0.5 * hash(origin.xz * 7.3)) * grow;

	// Conifers on the uplands, round trees below; a random one of the three.
	float lift = h - sea_level;
	float variant = lift > 1.8 ? 3.0 : floor(hash(origin.xz * 5.9) * 3.0);
	vec2 cell = vec2(mod(variant, 2.0), floor(variant / 2.0));
	atlas_uv = (UV + cell) * 0.5;

	// Stand the card up facing the camera, turning only about the up axis.
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 local = (VERTEX.x * right + vec3(0.0, VERTEX.y, 0.0)) * size;
	float base = surface_y(h) - 0.02;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(origin + local + vec3(0.0, base, 0.0), 1.0)).xyz;
	// Trees in a crowd sit a little darker, like the shade under a canopy.
	shade = 0.9 + 0.1 * hash(origin.xz * 2.3);
}

void fragment() {
	vec4 c = texture(atlas, atlas_uv);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = srgb_to_linear(c.rgb * shade);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// The sprites carry their own painted light; just a touch of sun and shade.
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * (0.75 + 0.25 * smoothstep(-0.3, 0.3, ndl)) * ATTENUATION;
}
