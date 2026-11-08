shader_type spatial;
// The hunters' version of toon.gdshader (Models.hunter swaps it in): the same painted lighting,
// tuned like a hero shooter's characters. A crisper light/shadow split, shadows that keep their
// colour instead of going grey, a coloured fresnel rim that outlines every form against the ground
// (strongest on edges the high match camera sees side-on), a soft top light on shoulders, heads and
// helms, and a tighter, brighter highlight on metal. Without the texture recolour and kin marks.
// Stylized painted lighting: warm key light, cool coloured shadows, light from the sky above and a
// darker underside, a whisper of hand-painted variation, a clean three-tone ramp with a soft
// terminator and a band of warm "subsurface" glow where light turns to shadow, a crisp rim that
// catches the key and fill lights, and an optional glossy highlight. Plus the hit flash.
uniform vec4 albedo : source_color = vec4(1.0);
// a Warden's 3D model (WardenGlb): its painted atlas, multiplied by albedo (the player's colour pick)
uniform bool use_tex = false;
// how much the sun's shadow map darkens this surface (1: fully). A scanned 3D Warden's smooth-shaded low-poly
// surface catches self-shadow acne in triangle-shaped patches; its painted atlas carries its own shade instead
uniform float self_shadow = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_nrm = false;       // a baked normal map (fine relief: stitches, seams), when the .glb has one
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float normal_k = 1.0;     // its strength (NORMAL_MAP_DEPTH); a look can set it per slot
uniform bool use_vertex_color = false;
uniform bool vertex_ao = false;    // characters: the vertex colour holds baked ambient occlusion (HeroKit)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_amount = 0.35;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float glow = 0.0;
// a painted atlas's glow slot (WardenGlb): only its hot texels glow (the cracks), not the dark skin or rock painted
// between them
uniform bool glow_key = false;
// a Warden's glow colours (WardenGlb, the archetype's "model_glow"; alpha 0: the painted colour): the hot texels and
// flat glow pieces take the core colour, their soft edges the edge colour, so the glow can change without a rebake
uniform vec4 glow_core : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 glow_edge : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float shade = 0.42;
uniform bool no_fog = false;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.9, 1.0);   // shadows lean cool and violet
uniform vec4 light_tint : source_color = vec4(1.05, 1.0, 0.93, 1.0);    // light leans warm
uniform float paint = 0.035;    // how much the colour wanders across a surface
uniform float sky_ao = 0.22;    // undersides darker, tops lit by the sky
uniform float gloss = 0.0;      // 0 matte .. 1 shiny (a crisp highlight band)
uniform float sss = 0.18;       // warm glow along the terminator (skin, fur, soft things)
uniform vec4 sss_color : source_color = vec4(1.0, 0.45, 0.32, 1.0);
uniform float sheen = 0.06;
// hero tuning
uniform float ramp = 1.0;          // 1 = toon.gdshader's soft terminator, smaller = crisper
uniform float shadow_sat = 0.0;    // extra saturation in shadow (no muddy greys)
uniform float fres = 0.0;          // coloured fresnel rim, independent of the lights
uniform vec4 fres_color : source_color = vec4(0.75, 0.86, 1.0, 1.0);
uniform float fres_tint = 0.5;     // 0 = fres_color, 1 = a lightened version of the surface's own colour
uniform float top_light = 0.0;     // surfaces facing up (what the match camera sees most) lift a little     // a soft broad highlight on every surface facing the light
// a painted atlas (WardenGlb) at the match camera (~23 m): its colours this much brighter and richer, fading in
// from 8 to 18 m away (close-ups keep the paint's own values)
uniform float far_lift = 0.0;
// the emission layer brighter and more saturated at the match camera (8 to 18 m away; a Warden's own look: Sparkle's
// pink scar, charm and piping pop against her blacks at match zoom)
uniform float far_emit = 0.0;
// a painted atlas (WardenGlb) carries the art's own colours, and the scene's light leans cool: its ambient (Look:
// c4cbe6, the biomes' lavender and blue) is about half the light on such a model and turned skin lilac. ambient_cut
// takes the scene's ambient off (through AO, which only scales ambient light) and own_ambient puts a warm-neutral
// one back (linear, added as emission); light_neutral takes the hue out of cool lights only (the blue fill), so the
// warm key keeps its warmth
uniform float ambient_cut = 0.0;
uniform vec3 own_ambient = vec3(0.0);
uniform float light_neutral = 0.0;
uniform float light_neutral_warm = 0.0;   // the same for warm lights (per model: black cloth under an orange sun)
// the painted colour pulled this far toward its own grey before the lights (per model, warden_look.json: a slot
// the warm light and the tonemap push too saturated, Tarek's brown skin reading orange-red); 0 = unchanged
uniform float desat = 0.0;
// a painted colour that glows (per model: Vex's circuit tattoos on her skin read at night): texels within
// paint_glow_width of paint_glow_color take paint_glow x their colour as emission; 0 = none (Vex r3h's glow_key,
// renamed: glow_key is the hot-texel switch)
uniform float paint_glow = 0.0;
uniform vec4 paint_glow_color : source_color = vec4(0.3, 0.76, 0.37, 1.0);
uniform float paint_glow_width = 0.12;
// near-black paint lifted to this linear floor (jacket, trousers and gun no longer merge to black at the match
// camera); mid and light colours keep their value and saturation
uniform float dark_lift = 0.0;
// a painted atlas at the match camera (~2 cm a pixel at 23 m): its fine detail (belts, bullets, tattoos, the scan's
// grain) breaks into speckle, so from ~8 to 18 m the texture blends toward a coarser mip of itself (far_smooth of
// the way, far_smooth_bias mips up; more than ~1 mip mixes a baked atlas's UV islands into mud); close-ups keep
// every texel
uniform float far_smooth = 0.0;
uniform float far_smooth_bias = 1.0;
// and a rim in the Hunter's signature colour there (content/rules/warden_look.json), so the silhouette holds
uniform float rim_far = 0.0;
uniform vec4 rim_far_color : source_color = vec4(1.0);
// The match camera's clean read (WardenGlb.PAINTED; every default changes nothing). At ~2 cm a pixel the view-
// dependent terms of a dense scanned mesh flip per pixel: the fresnel and light rims, the gloss band on metal and
// the sheen came out as white and dark speckle along every edge. From 8 to 18 m: far_fres scales the shared
// fresnel (its pale lightened-own-colour rim washed hair and edges out), far_spec the gloss, sheen and the lights'
// rims, far_aa widens what is left by its own screen derivative, far_clamp pulls a texel that stands out of its
// coarser mip back toward it (a white bullet, a black belt pixel: speckle) without a wider blur (no UV-island mud).
// far_rim_soft turns rim_far into a broad, saturated band in the signature colour (lit albedo leaning to it, a little
// of it as emission) instead of a pale hairline added on top. far_glow brightens and saturates what glows (glow x
// the painted colour: eyes, lenses, cracks) there. These go by the size on screen, not the distance (match_d), so
// a close-up camera far off with a narrow lens (the hunter viewer, --warden-shots) keeps every line and highlight.
uniform float far_fres = 1.0;
uniform float far_spec = 1.0;
uniform float far_aa = 0.0;
uniform float far_clamp = 0.0;
uniform float far_rim_soft = 0.0;
uniform float far_glow = 0.0;
// Imported low-poly models carry each corner's averaged (smooth) normal in TANGENT (Assets.mesh).
// Blending toward it rounds off their facets in the shading while the silhouette stays crisp.
uniform float soften = 0.0;
// Hand-painted value structure (characters): each part is lighter at its top and darker at its foot,
// darkest right where it tucks into the next part (UV2 holds the part's height range, set when
// the model is built); edges turned away from the eye darken like a painted form shadow; and a
// surface "material" adds its own brushwork: 1 cloth, 2 leather, 3 metal, 4 skin, 5 hair, 6 gem.
uniform float part_grad = 0.0;
uniform float crease = 0.0;
uniform float edge_dark = 0.0;
uniform int surface = 0;
// a painted emission layer on a .glb's atlas (Sparkle's lightning veins and hair crackle, Tarek's bracer cracks):
// its texture x emit, crackling over time by emit_flicker (0 steady .. 1 strobing along the body)
uniform bool use_emit = false;
uniform sampler2D emit_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float emit = 0.0;
uniform float emit_flicker = 0.0;
// the emission layer's colour (WardenGlb, the archetype's "model_glow" core; alpha 0: the layer's own painted colour):
// the layer is then a mask, and its texels' paint takes the colour too, so the glow can change without a rebake (Sparkle)
uniform vec4 emit_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/vis.gdshaderinc"
// The distance at which the match camera's 32 degree lens sees things this size on screen: the far_* terms' measure
// (abs: the projection's y is flipped when drawing into a texture; an orthographic camera: its view height / 0.57)
float match_d(vec3 v, mat4 proj) {
	return proj[3][3] > 0.5 ? 6.97 / abs(proj[1][1]) : length(v) * 3.487 / abs(proj[1][1]);
}
varying vec3 lpos;
varying vec3 wnorm;
varying vec2 part_y;
varying float far_l;    // (fragment -> light: the match camera's share, far_spec)

void vertex() {
	if (soften > 0.0) { NORMAL = normalize(mix(NORMAL, TANGENT, soften)); }
	lpos = VERTEX;
	part_y = UV2;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (use_nrm) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_k;
	}
	vec3 c = albedo.rgb;
	float heat = 1.0;
	float far_k = smoothstep(8.0, 18.0, length(VERTEX));
	float far_p = smoothstep(8.0, 18.0, match_d(VERTEX, PROJECTION_MATRIX));
	if (use_tex) {
		vec3 tx = texture(albedo_tex, UV).rgb;
		if (far_smooth > 0.0 && far_k > 0.001) {
			vec3 tc = texture(albedo_tex, UV, far_smooth_bias).rgb;
			if (far_clamp > 0.0) {
				vec3 tr = vec3(mix(1.0, 0.06, far_clamp * far_p));
				tx = clamp(tx, tc - tr, tc + tr);
			}
			tx = mix(tx, tc, far_smooth * far_k);
		}
		c *= tx;
		if (glow_key) {
			// (the cracks' red-orange rims count too: in a white-hot glow they take the edge colour, not the paint)
			heat = smoothstep(0.42, 0.66, tx.r) * smoothstep(0.14, 0.32, tx.r - tx.b) * smoothstep(-0.04, 0.01, tx.g - tx.b);
		}
	}
	vec3 emit_c = vec3(0.0);
	if (use_emit) {
		emit_c = texture(emit_tex, UV).rgb;
		if (emit_tint.a > 0.0) {
			float ek = max(emit_c.r, max(emit_c.g, emit_c.b));
			// (a yellow piece keeps its own colour: Sparkle's hazard bands glow faintly as painted)
			float yel = smoothstep(0.08, 0.2, min(emit_c.r, emit_c.g) - emit_c.b);
			c = mix(c, emit_tint.rgb, smoothstep(0.2, 0.7, ek) * 0.85 * (1.0 - yel));
			emit_c = mix(emit_tint.rgb * ek, emit_c, yel);
		}
	}
	if (glow_core.a > 0.0 && glow > 0.0) {
		vec3 hot = mix(glow_edge.a > 0.0 ? glow_edge.rgb : glow_core.rgb, glow_core.rgb, smoothstep(0.35, 0.9, heat));
		c = mix(c, hot, glow_key ? heat : 1.0);
	}
	if (use_vertex_color || vertex_ao) { c *= COLOR.rgb; }
	if (desat > 0.0) { c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), desat); }
	if (dark_lift > 0.0) {
		float dl = dot(c, vec3(0.3, 0.59, 0.11));
		c += max(vec3(dark_lift) - c, vec3(0.0)) * (1.0 - smoothstep(0.0, dark_lift * 2.5, dl));
	}
	// hand-painted variation: soft blotches of slightly lighter and darker paint
	float n = vnoise(lpos.xz * 7.0 + lpos.y * 4.0) * 0.6 + vnoise(lpos.xy * 15.0 + 3.1) * 0.4;
	c *= 1.0 + (n - 0.5) * 2.0 * paint;
	// sky light from above, a little bounce from below: shapes read as solid from the high camera
	c *= mix(1.0 - sky_ao, 1.0 + sky_ao * 0.3, wnorm.y * 0.5 + 0.5);
	// painted value structure: light at the top of each part, dark at its foot and in the crease
	if (part_y.y - part_y.x > 0.0001 && (part_grad > 0.0 || crease > 0.0)) {
		float g = clamp((lpos.y - part_y.x) / (part_y.y - part_y.x), 0.0, 1.0);
		c *= mix(1.0 - part_grad, 1.0 + part_grad * 0.45, g);
		c *= 1.0 - (1.0 - smoothstep(0.0, 0.3, g)) * crease;
	}
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c *= 1.0 - smoothstep(0.45, 0.95, 1.0 - nv) * edge_dark;
	// brushwork per material, faded out where it would shimmer at a distance
	if (surface > 0) {
		float fw = fwidth(lpos.y) * 60.0;
		float near_k = 1.0 - smoothstep(0.35, 1.2, fw);
		if (surface == 1) {          // cloth: soft vertical strokes and a faint weave
			float st = vnoise(vec2((lpos.x + lpos.z) * 38.0, lpos.y * 7.0));
			c *= 1.0 + (st - 0.5) * 0.16 * near_k;
		} else if (surface == 2) {   // leather: mottled, darker in patches
			float st = vnoise(lpos.xz * 46.0 + lpos.y * 31.0) * 0.6 + vnoise(lpos.xy * 90.0) * 0.4;
			c *= 1.0 + (st - 0.55) * 0.22 * near_k;
		} else if (surface == 3) {   // metal: a painted sky-and-ground reflection and brushed streaks
			vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
			float env = smoothstep(-0.35, 0.55, r.y);
			c *= mix(0.55, 1.35, env);
			float st = vnoise(vec2(lpos.x * 6.0, (lpos.y + lpos.z) * 70.0));
			c *= 1.0 + (st - 0.5) * 0.14 * near_k;
		} else if (surface == 5) {   // hair and fur: strands
			float st = vnoise(vec2((lpos.x - lpos.z) * 70.0, lpos.y * 9.0));
			c *= 1.0 + (st - 0.5) * 0.2 * near_k;
		} else if (surface == 6) {   // gems: a bright inner facet glow
			vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
			c *= 0.8 + 0.6 * smoothstep(0.1, 0.8, r.y);
		}
	}
	if (far_lift > 0.0) {
		float far_k = far_lift * smoothstep(8.0, 18.0, length(VERTEX));
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		c = max(mix(vec3(lum), c, 1.0 + far_k * 0.6), vec3(0.0)) * (1.0 + far_k);
	}
	float fog = no_fog ? 0.0 : vis_fog((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	c = vis_apply(c, fog);
	ALBEDO = mix(c, flash_color.rgb, flash);
	// a faint rim everywhere (so silhouettes lift off dark ground even in shadow); the crisp,
	// light-facing rim is added per light below
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 vdir = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	// side-on to the camera, and more so on the sides of forms than their tops and bottoms
	float side = 1.0 - abs(dot(wnorm, normalize(vec3(vdir.x, 0.0, vdir.z) + vec3(0.0001))));
	float aw = fwidth(nv) * far_aa * far_p;
	float fr = smoothstep(0.62 - aw, 0.84 + aw, 1.0 - nv) * mix(0.55, 1.0, side) * (1.0 - fog);
	far_l = far_p;
	// the signature rim at the match camera: a broad band on the forms' turned-away sides (far_rim_soft), the
	// lit colour leaning to the signature hue and a little of it glowing, so it reads saturated, not pale
	float frs = smoothstep(0.3, 0.8, 1.0 - nv) * mix(0.6, 1.0, side) * (1.0 - fog) * rim_far * far_p * far_rim_soft;
	if (frs > 0.0) {
		vec3 rim_al = rim_far_color.rgb * max(dot(ALBEDO, vec3(0.3, 0.59, 0.11)) * 1.5, 0.5);
		ALBEDO = mix(ALBEDO, rim_al, min(frs * 2.2, 0.8) * (1.0 - flash));
	}
	vec3 fcol = mix(fres_color.rgb, min(c * 1.7 + vec3(0.12), vec3(1.4)), fres_tint);
	float up = smoothstep(0.35, 0.95, wnorm.y);
	if (ambient_cut > 0.0) { AO = 1.0 - ambient_cut; }
	EMISSION = flash_color.rgb * flash * 0.9 + c * glow * heat + c * own_ambient * (1.0 - fog)
		+ rim_color.rgb * rim * rim_amount * 0.12 * (1.0 - fog)
		+ fcol * fr * fres * 0.55 + c * up * top_light * 0.18 * (1.0 - fog)
		+ rim_far_color.rgb * fr * rim_far * far_k;
	if (use_emit) {
		float fl = vnoise(vec2(TIME * 7.0 + lpos.y * 5.0, lpos.x * 3.0 + lpos.z * 3.0));
		vec3 ec = emit_c;
		if (far_emit > 0.0) {
			float fe = far_emit * smoothstep(8.0, 18.0, length(VERTEX));
			float el = dot(ec, vec3(0.3, 0.59, 0.11));
			ec = max(mix(vec3(el), ec, 1.0 + fe * 0.5), vec3(0.0)) * (1.0 + fe);
		}
		EMISSION += ec * emit * (1.0 - emit_flicker * (1.0 - smoothstep(0.25, 0.6, fl)));
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	if (paint_glow > 0.0) {
		float pg = 1.0 - smoothstep(paint_glow_width, paint_glow_width * 2.0, distance(c, paint_glow_color.rgb));
		EMISSION += c * paint_glow * pg;
	}
	// the match camera's read (far_*, above): the pale fresnel and the faint rim scaled down, rim_far's hairline
	// swapped for its broad band, the glow brighter and richer
	if (far_p > 0.0) {
		vec3 gc = c * glow * heat;      // (a hot-keyed glow: only its hot texels, as above)
		float fg = far_glow * far_p;
		vec3 gf = max(mix(vec3(dot(gc, vec3(0.3, 0.59, 0.11))), gc, 1.0 + fg * 0.5), vec3(0.0)) * (1.0 + fg);
		EMISSION += fcol * fr * fres * 0.55 * (far_fres - 1.0) * far_p
			+ rim_color.rgb * rim * rim_amount * 0.12 * (1.0 - fog) * (far_spec - 1.0) * far_p
			- rim_far_color.rgb * fr * rim_far * far_k * far_rim_soft + rim_far_color.rgb * frs * 0.6
			+ (gf - gc) * step(0.0001, glow);
	}
}

void light() {
	vec3 lc = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.3, 0.59, 0.11))),
		light_neutral * step(LIGHT_COLOR.r, LIGHT_COLOR.b)
		+ light_neutral_warm * (1.0 - step(LIGHT_COLOR.r, LIGHT_COLOR.b)));
	if (!LIGHT_IS_DIRECTIONAL) {
		// lamps and glows: plain falloff. (The cel shade floor below is only for the sun; on a lamp
		// it lit whole screen clusters at once, which showed up as blocky squares at night.)
		float pl = smoothstep(-0.1, 0.4, dot(NORMAL, LIGHT)) * ATTENUATION;
		DIFFUSE_LIGHT += ALBEDO * lc / PI * pl;
	} else {
		float ndl = dot(NORMAL, LIGHT);
		float sh_att = mix(1.0, ATTENUATION, self_shadow);
		// the main split: a soft but clean terminator, then a gentle lift on faces turned to the light
		float lit = smoothstep(-0.03 * ramp, 0.16 * ramp, ndl) * sh_att;
		float band = smoothstep(mix(0.42, 0.2, ramp), mix(0.58, 0.8, ramp), lit);
		float face = smoothstep(0.42, 0.78, ndl) * sh_att;
		vec3 tone = mix(vec3(shade) * shadow_tint.rgb, light_tint.rgb, band) * mix(0.93, 1.06, face);
		// warm light bleeding through just past the terminator, like skin or fur
		float term = smoothstep(-0.34, 0.02, ndl) * (1.0 - smoothstep(0.02, 0.32, ndl)) * mix(0.35, 1.0, sh_att);
		tone += sss_color.rgb * term * sss;
		vec3 al = ALBEDO;
		if (shadow_sat > 0.0) {
			float lum = dot(al, vec3(0.3, 0.59, 0.11));
			al = mix(max(mix(vec3(lum), al, 1.0 + shadow_sat), vec3(0.0)), al, band);
		}
		DIFFUSE_LIGHT += al * lc / PI * tone;
		// a crisp rim on the edge that faces this light (key light rims gold, the fill rims cool)
		float fr_l = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim_l = smoothstep(0.7, 0.8, fr_l) * smoothstep(-0.25, 0.45, ndl);
		float fs = mix(1.0, far_spec, far_l);
		DIFFUSE_LIGHT += rim_color.rgb * lc * rim_l * rim_amount * 0.24 * mix(0.45, 1.0, sh_att) * fs;
		vec3 hv = normalize(LIGHT + VIEW);
		float nh = max(dot(NORMAL, hv), 0.0);
		SPECULAR_LIGHT += lc * pow(nh, 16.0) * sheen * band * fs;
		if (gloss > 0.0) {
			float sp = pow(nh, mix(14.0, 110.0, gloss));
			SPECULAR_LIGHT += lc * (smoothstep(0.42, 0.52, sp) * 0.55 + sp * 0.25) * gloss * band * sh_att * fs;
		}
	}
}
