shader_type spatial;

// Grey-box floor: a one-metre grid with a bolder line every five, fixed to the world so that
// movement and speed can be read against it.

uniform vec3 base : source_color = vec3(0.36, 0.38, 0.42);
uniform vec3 fine : source_color = vec3(0.31, 0.33, 0.37);
uniform vec3 bold : source_color = vec3(0.24, 0.26, 0.3);

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float lines(vec2 p, float cell, float width) {
	vec2 d = abs(fract(p / cell + 0.5) - 0.5) * cell;
	return 1.0 - smoothstep(width, width + 0.02, min(d.x, d.y));
}

void fragment() {
	vec3 c = mix(base, fine, lines(world.xz, 1.0, 0.02));
	ALBEDO = mix(c, bold, lines(world.xz, 5.0, 0.04));
	ROUGHNESS = 0.9;
}
