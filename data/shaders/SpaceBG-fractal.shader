shader_type canvas_item;

uniform int iterations = 17;
uniform float formuparam = 0.53;
uniform int volsteps = 20;
uniform float stepsize = 0.1;
uniform float zoom = 0.8;
uniform float tile = 0.850;
uniform float speed = 0.001;
uniform float brightness = 0.0015;
uniform float darkmatter = 0.300;
uniform float distfading = 0.730;
uniform float saturation = 0.850;

uniform vec2 camera_offset;

varying highp vec2 high_uv;

void vertex() {
	high_uv = UV;
}

void fragment() {
	highp vec2 uv = high_uv;// / 1000.0;
	//uv = uv / SCREEN_PIXEL_SIZE * 2.0;
	//uv.y *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	highp vec3 dir = vec3(uv*zoom, 1.);
	highp vec2 time = camera_offset * speed / 10240.0;
	
	highp vec3 from = vec3(1., 0.5, 0.5);
	from += vec3(time.x, time.y, -2.);
	
	float s = 0.1;
	float fade = 1.0;
	
	highp vec3 v = vec3(0.);
	highp vec3 p;
	highp float pa = 0.;
	highp float a = 0.;
	highp float a_sqr;
	highp float dm;
	for (int r=0; r < volsteps; r++) {
		p = from + s * dir * 0.5;
		p = abs(vec3(tile) - mod(p, vec3(tile * 2.)));
		pa = 0.;
		a = 0.;
		
		for (int i=0; i < iterations; i++) {
			p = abs(p) / dot(p, p) - formuparam;
			a += abs(length(p)-pa);
			pa = length(p);
		}
		
		a_sqr = a * a;
		dm = max(0., darkmatter - a_sqr * 0.001);
		a *= a_sqr;
		if (r > 6) {
			fade *= 1. - dm;
		}
		v += fade;
		v += vec3(s, s*s, s*s*s*s)*a*brightness*fade;
		fade *= distfading;
		s += stepsize;
	}
	
	v = mix(vec3(length(v)), v, saturation);
	COLOR = vec4(v * 0.01, 1.);
}