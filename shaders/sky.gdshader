shader_type sky;

// A painted sky: deep blue overhead fading to a pale haze at the horizon,
// with big soft clouds lit from above.
uniform vec3 zenith_color : source_color = vec3(0.40, 0.62, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.81, 0.89);
uniform vec3 cloud_light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.62, 0.72, 0.86);

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
	for (int i = 0; i < 5; i++) {
		value += amp * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return value;
}

void sky() {
	float up = EYEDIR.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.45, up));
	if (up > 0.0) {
		// Clouds on a flat layer overhead, squashed towards the horizon.
		// Static on purpose: animating the sky makes Godot re-render it every frame.
		vec2 uv = EYEDIR.xz / (up + 0.12) * 1.4;
		float c = fbm(uv);
		float cloud = smoothstep(0.5, 0.62, c) * smoothstep(0.0, 0.08, up);
		// Lit tops, bluish undersides.
		float lit = smoothstep(0.5, 0.75, fbm(uv + vec2(0.04, 0.06)) - c + 0.55);
		vec3 cloud_col = mix(cloud_shadow_color, cloud_light_color, lit);
		col = mix(col, cloud_col, cloud);
	}
	COLOR = col;
}
