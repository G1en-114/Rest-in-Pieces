// 地面石块：顶面是磨石地砖（斑点 + 砖缝），侧面是石头，越往下越暗、隐进雾里。
// 用在单位立方体缩放出来的方块上：网格是 1×1×1，大小全靠 MeshInstance 的缩放。
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.8, 0.78, 0.74);
uniform vec3 speck_a : source_color = vec3(0.35, 0.34, 0.33);
uniform vec3 speck_b : source_color = vec3(0.95, 0.94, 0.9);
uniform vec3 grout_color : source_color = vec3(0.55, 0.52, 0.5);
uniform vec3 side_color : source_color = vec3(0.78, 0.7, 0.66);
uniform float tile = 0.8;  // 地砖边长（米）
uniform float speck_density = 0.3;
uniform float roughness = 0.55;

varying vec3 wpos;
varying vec3 wnrm;
varying float depth_m;  // 侧面上这一点离顶面有多少米

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	depth_m = (0.5 - VERTEX.y) * length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	vec3 c;
	if (wnrm.y > 0.5) {
		vec2 uv = wpos.xz;
		// 斑点：每 12 厘米一格，随机一部分格子里有一粒石子
		vec2 cell = floor(uv * 8.0);
		vec2 f = fract(uv * 8.0) - 0.5;
		float h = hash(cell);
		float r = length(f + (vec2(hash(cell + 1.3), hash(cell + 5.1)) - 0.5) * 0.3);
		float aa = fwidth(r) * 1.5;
		float speck = (h < speck_density) ? 1.0 - smoothstep(0.18 - aa, 0.18 + aa, r) : 0.0;
		c = mix(base_color, mix(speck_a, speck_b, step(0.5, hash(cell + 7.7))), speck * 0.8);
		// 每块砖颜色略有出入，砖缝用 fwidth 抗锯齿，俯视缩小时不闪
		vec2 t = floor(uv / tile);
		c *= 0.95 + 0.07 * hash(t);
		vec2 g = abs(fract(uv / tile) - 0.5);
		float edge = max(g.x, g.y);
		float w = fwidth(edge);
		c = mix(c, grout_color, smoothstep(0.485 - w, 0.485 + w, edge));
		ROUGHNESS = roughness;
		SPECULAR = 0.45;
	} else if (wnrm.y < -0.5) {
		c = side_color * 0.35;
		ROUGHNESS = 1.0;
	} else {
		// 侧面：顶上一道浅色压边，下面一层层石砌，越深越暗
		c = side_color;
		float course = fract(depth_m / 0.55);
		float w = fwidth(depth_m / 0.55);
		c *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, w * 2.0 + 0.03, course));
		if (depth_m < 0.08) {
			c = side_color * 1.12;
		}
		c *= mix(1.0, 0.42, clamp(depth_m / 5.0, 0.0, 1.0));
		ROUGHNESS = 0.95;
	}
	ALBEDO = c;
}
