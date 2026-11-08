// The motion of the Hero VFX GPU particles (scripts/match/hero_vfx.gd): where they start, a push, drag, gravity and
// a curling drift, so a burst of embers wanders like heat rather than flying straight. TRANSFORM[0] carries the
// velocity for the draw pass (hero_vfx_mote.gdshader), which stretches sparks along it.
shader_type particles;
render_mode disable_force, disable_velocity;

uniform int shape = 0;            // 0 a ball, 1 a line (`span`), 2 a disc on the ground, 3 converging on the node, 4 an arc
                                  // (the node at its centre, `radius` out; span: half angle rad, yaw rad, depth m)
uniform float radius = 0.2;       // m
uniform vec3 span = vec3(0.0, 0.0, 1.0);    // m, the line from the node
uniform vec3 dir = vec3(0.0, 1.0, 0.0);
uniform float spread = 0.5;       // 0 along dir .. 1 every way
uniform float speed = 3.0;        // m/s at the most
uniform float gravity = 0.0;      // m/s^2, negative rises
uniform float drag = 1.0;         // /s
uniform float curl = 1.0;         // m/s^2 of drift
uniform float size = 0.1;         // m
uniform float size_var = 0.5;     // share of the size that is random
uniform float floor_y = -1.0e9;   // m, the ground under the emitter (hero_vfx.gd): a falling mote lands on it
const float LAND_BOUNCE = 0.25;   // share of the fall speed a landing mote bounces back up with
const float LAND_SKID = 0.6;      // share of its ground speed it keeps as it lands

uint hash_u(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	return (x >> uint(16)) ^ x;
}

float rnd(inout uint s) {
	s = hash_u(s);
	return float(s % uint(100000)) / 100000.0;
}

vec3 rnd_dir(inout uint s) {
	float z = rnd(s) * 2.0 - 1.0;
	float a = rnd(s) * 6.28318;
	float r = sqrt(1.0 - z * z);
	return vec3(r * cos(a), z, r * sin(a));
}

void start() {
	uint s = hash_u(NUMBER + RANDOM_SEED);
	vec3 at = vec3(0.0);
	vec3 way = normalize(mix(dir, rnd_dir(s), spread));
	float sp = speed * mix(0.45, 1.0, rnd(s));
	if (shape == 0) {
		at = rnd_dir(s) * radius * sqrt(rnd(s));
	} else if (shape == 1) {
		at = span * rnd(s) + rnd_dir(s) * radius;
	} else if (shape == 2) {
		float a = rnd(s) * 6.28318;
		float r = sqrt(rnd(s)) * radius;
		at = vec3(cos(a) * r, 0.05, sin(a) * r);
	} else if (shape == 4) {
		float a = span.y + (rnd(s) * 2.0 - 1.0) * span.x;
		float r = radius + (rnd(s) - 0.5) * span.z;
		at = vec3(sin(a) * r, 0.05, cos(a) * r);
	} else {
		vec3 out_way = rnd_dir(s);
		at = out_way * radius;
		way = -out_way;
	}
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xyz = (EMISSION_TRANSFORM * vec4(at, 1.0)).xyz;
	VELOCITY = way * sp;
	CUSTOM = vec4(size * mix(1.0 - size_var, 1.0 + size_var, rnd(s)), 0.0, rnd(s), mix(0.55, 1.0, rnd(s)));
	COLOR = vec4(1.0);
}

void process() {
	CUSTOM.y += DELTA;
	float age = CUSTOM.y / (LIFETIME * CUSTOM.w);
	if (age >= 1.0) { ACTIVE = false; }
	vec3 p = TRANSFORM[3].xyz;
	float ph = CUSTOM.z * 6.28318;
	vec3 drift = vec3(sin(p.y * 2.3 + TIME * 2.0 + ph), 0.0, cos(p.x * 2.1 + p.z * 1.7 + TIME * 1.7 + ph));
	VELOCITY += (drift * curl + vec3(0.0, -gravity, 0.0)) * DELTA;
	VELOCITY *= max(0.0, 1.0 - drag * DELTA);
	TRANSFORM[3].xyz += VELOCITY * DELTA;
	float rest = floor_y + CUSTOM.x * 0.5;
	if (TRANSFORM[3].y < rest && VELOCITY.y < 0.0) {     // lands and skids instead of sinking through the ground
		TRANSFORM[3].y = rest;
		VELOCITY *= vec3(LAND_SKID, -LAND_BOUNCE, LAND_SKID);
	}
	TRANSFORM[0] = vec4(VELOCITY, 0.0);
	TRANSFORM[1] = vec4(CUSTOM.x, age, 0.0, 0.0);
	TRANSFORM[2] = vec4(CUSTOM.z, 0.0, 0.0, 0.0);
}
