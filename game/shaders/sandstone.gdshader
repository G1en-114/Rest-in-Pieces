// 埃及的砂岩墙：一层层错缝砌的石块，墙腰一道象形文字饰带（上下各压一条蓝金色线），墙顶压一条深色石板。
// 象形文字是程序画的：饰带切成一格一格，每格随机画一个简单符号（眼睛、水波、圆盘、羽毛、手杖……）。
// 用在单位立方体缩放出来的方块上；水平方向用世界坐标 x + z，所以沿 X 和沿 Z 的墙都能用。
shader_type spatial;

uniform vec3 stone : source_color = vec3(0.86, 0.7, 0.48);
uniform vec3 mortar : source_color = vec3(0.66, 0.5, 0.33);
uniform vec3 glyph : source_color = vec3(0.32, 0.2, 0.12);
uniform vec3 band_blue : source_color = vec3(0.16, 0.36, 0.62);
uniform vec3 band_gold : source_color = vec3(0.95, 0.74, 0.25);
uniform vec3 cap : source_color = vec3(0.55, 0.42, 0.3);
uniform float course = 0.4;  // 一层石块多高（米）
uniform float frieze_y = 0.9;  // 饰带下沿离墙脚多高
uniform float frieze_h = 0.42;  // 饰带多高（0 = 不要饰带）

varying vec3 wpos;
varying vec3 wnrm;
varying float y_m;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 一格里的符号：uv 在 0~1，返回 1 表示画上颜色
float glyph_shape(vec2 uv, float k) {
	vec2 c = uv - 0.5;
	float r = length(c);
	if (k < 0.16) {  // 圆盘（太阳）
		return step(r, 0.26);
	} else if (k < 0.32) {  // 水波：三道锯齿横线
		float y = fract(uv.y * 3.0) - 0.5;
		float wave = abs(fract(uv.x * 4.0) - 0.5) * 0.5 - 0.12;
		return step(abs(y - wave), 0.07) * step(0.15, uv.y) * step(uv.y, 0.85);
	} else if (k < 0.48) {  // 眼睛：杏仁形外框 + 眼珠
		float e = length(c * vec2(1.0, 2.2));
		return max(step(abs(e - 0.3), 0.05), step(r, 0.09));
	} else if (k < 0.64) {  // 羽毛：竖着的细长椭圆
		return step(length(c * vec2(3.2, 1.0)), 0.42);
	} else if (k < 0.8) {  // 手杖：竖杆 + 顶上的弯钩
		float stick = step(abs(c.x), 0.06) * step(abs(c.y), 0.4);
		float hook = step(abs(length(c - vec2(0.12, -0.3)) - 0.12), 0.05) * step(c.y, -0.3);
		return max(stick, hook);
	} else {  // 生命之符：圈 + 十字
		float loop = step(abs(length((c - vec2(0.0, -0.2)) * vec2(1.3, 1.0)) - 0.13), 0.05);
		float bar = step(abs(c.y + 0.02), 0.05) * step(abs(c.x), 0.26);
		float stem = step(abs(c.x), 0.06) * step(-0.02, c.y) * step(c.y, 0.42);
		return max(loop, max(bar, stem));
	}
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	y_m = (VERTEX.y + 0.5) * length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	vec3 c;
	if (wnrm.y > 0.5) {
		c = cap;
		ROUGHNESS = 0.7;
	} else {
		float u = wpos.x + wpos.z;
		// 错缝砌的石块
		float row = floor(y_m / course);
		float bu = u / (course * 2.2) + hash(vec2(row, 3.0)) + row * 0.5;
		vec2 f = vec2(fract(bu), fract(y_m / course));
		float w = fwidth(y_m / course) * 1.5;
		float joint = 1.0 - smoothstep(0.0, 0.035 + w, min(min(f.x, 1.0 - f.x) * 2.2, min(f.y, 1.0 - f.y)));
		c = mix(stone * mix(0.9, 1.06, hash(vec2(floor(bu), row))), mortar, joint);
		// 饰带
		float fy = y_m - frieze_y;
		if (frieze_h > 0.0 && fy > -0.06 && fy < frieze_h + 0.06) {
			if (fy < 0.0 || fy > frieze_h) {
				float stripe = fy < 0.0 ? -fy : fy - frieze_h;
				c = stripe < 0.03 ? band_gold : band_blue;
			} else {
				vec2 cell = vec2(u / frieze_h * 1.4, fy / frieze_h);
				vec2 id = floor(cell);
				vec2 uv = fract(cell);
				uv = (uv - 0.5) * 1.25 + 0.5;
				float k = hash(id + 7.0);
				float g = glyph_shape(uv, k) * step(0.0, uv.x) * step(uv.x, 1.0);
				c = mix(c * 1.04, glyph, g);
			}
		}
		c *= mix(0.75, 1.0, smoothstep(0.0, 0.6, y_m));  // 墙脚一点假的环境光遮蔽
		ROUGHNESS = 0.9;
	}
	ALBEDO = c;
}
