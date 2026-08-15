shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.55, 0.72, 0.78);
uniform vec4 deep_color : source_color = vec4(0.06, 0.18, 0.32, 0.92);
uniform vec4 foam_color : source_color = vec4(0.82, 0.94, 1.0, 0.85);
uniform float wave_height = 0.045;
uniform float wave_scale = 0.55;
uniform float wave_speed = 0.85;
uniform float sparkle_strength = 0.35;
uniform float metallic_amount = 0.42;
uniform float roughness_amount = 0.18;

varying float v_depth;
varying float v_shore;
varying vec3 v_world;

void vertex() {
	v_depth = COLOR.r;
	v_shore = COLOR.g;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w1 = sin(world.x * wave_scale * 2.1 + TIME * wave_speed)
		* cos(world.z * wave_scale * 1.7 - TIME * wave_speed * 0.85);
	float w2 = sin((world.x + world.z) * wave_scale * 3.4 + TIME * wave_speed * 1.35) * 0.45;
	VERTEX.y += (w1 + w2) * wave_height * mix(0.55, 1.0, v_depth);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = clamp(v_depth, 0.0, 1.0);
	float shore = clamp(v_shore, 0.0, 1.0);

	vec3 base = mix(shallow_color.rgb, deep_color.rgb, depth);
	float alpha = mix(shallow_color.a, deep_color.a, depth);

	// Soft traveling caustics / sparkle.
	float c1 = sin(v_world.x * 3.2 + TIME * 1.6) * cos(v_world.z * 2.7 - TIME * 1.2);
	float c2 = sin((v_world.x - v_world.z) * 5.5 + TIME * 2.1);
	float sparkle = smoothstep(0.55, 0.95, c1 * 0.5 + c2 * 0.5);
	base += vec3(0.35, 0.55, 0.65) * sparkle * sparkle_strength * (1.0 - depth * 0.5);

	// Shore foam band.
	float foam_pulse = 0.65 + 0.35 * sin(TIME * 3.0 + v_world.x * 2.0 + v_world.z * 1.5);
	float foam = shore * foam_pulse;
	base = mix(base, foam_color.rgb, foam * 0.85);
	alpha = mix(alpha, foam_color.a, foam * 0.5);

	// Fake fresnel rim toward camera.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	base = mix(base, vec3(0.75, 0.9, 1.0), fresnel * 0.28);
	alpha = mix(alpha, min(alpha + 0.12, 0.96), fresnel);

	ALBEDO = base;
	ALPHA = alpha;
	METALLIC = metallic_amount;
	ROUGHNESS = mix(roughness_amount, 0.45, shore);
	SPECULAR = 0.7;
}
