// 殡仪馆的墙：上白下蓝绿（机关单位那种墙裙），中间一道细腰线，底下一截深色踢脚线，墙顶压一条深色石板。
// 用在单位立方体缩放出来的方块上。
shader_type spatial;

uniform vec3 upper : source_color = vec3(0.95, 0.93, 0.88);
uniform vec3 lower : source_color = vec3(0.42, 0.62, 0.62);
uniform vec3 trim : source_color = vec3(0.2, 0.32, 0.33);
uniform vec3 skirting : source_color = vec3(0.24, 0.17, 0.13);
uniform vec3 cap : source_color = vec3(0.32, 0.3, 0.3);
uniform float band_height = 0.85;  // 墙裙高度（米）

varying vec3 wnrm;
varying float y_m;  // 离墙脚多少米

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	y_m = (VERTEX.y + 0.5) * length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	vec3 c;
	if (wnrm.y > 0.5) {
		c = cap;
		ROUGHNESS = 0.5;
	} else if (wnrm.y < -0.5) {
		c = skirting;
	} else {
		float w = fwidth(y_m);
		c = upper;
		c = mix(trim, c, smoothstep(band_height + 0.04 - w, band_height + 0.04 + w, y_m));
		c = mix(lower, c, smoothstep(band_height - w, band_height + w, y_m));
		c = mix(skirting, c, smoothstep(0.12 - w, 0.12 + w, y_m));
		c *= mix(0.78, 1.0, smoothstep(0.0, 0.7, y_m));  // 墙脚一点假的环境光遮蔽
		ROUGHNESS = 0.85;
	}
	ALBEDO = c;
}
