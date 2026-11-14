class_name LevelUpCue
extends RefCounted
## Your level-up moment (Hunter.gain_xp -> Hud.level_up), the one place it is told: a gold light column
## with chevrons rising over your hero, and a short card just over the vitals (above the XP tracker) saying
## what improved (health and ability power, the weapon's step, the ultimate opening, points to spend). It is gone in
## LIFE s. No toast and no screen wash; the sound is Hunter's, the world glow is Fx.body_glow.
## Hud keeps one (hud.lvl_cue); checks read `t` and `lines`.

const LIFE := 2.6          # s the card is up, its fade included
const FADE := 0.5          # s of fade at the end of the card
const POP := 0.18          # s the card takes to pop in
const BODY := 0.8          # s of the light column over the hero
const COL_W := 46.0        # px: the light column's width
const COL_H := 150.0       # px: how far the chevrons rise over the hero's feet
const CARD_GAP := 10.0     # px between the card and the health number under it

var t := 0.0               # s left on the card (0: nothing shown)
var lines: Array = []      # [title, gains, news]; news may be ""

## A level was reached: what the card will say.
func start(p: Hunter, lv: int, info: Dictionary) -> void:
	lines = text_for(p, lv, info)
	t = LIFE

static func text_for(p: Hunter, lv: int, info: Dictionary) -> Array:
	var hp_gain := roundi(LevelGrowth.step("hp", lv) * 100.0)
	var gains := "+%d%% health   +%d%% ability power" % [hp_gain, roundi(LevelGrowth.step("ap", lv) * 100.0)]
	var news: Array = []
	if info.has("name"):
		news.append("%s: %s" % [String(p.wpn["name"]), info["name"]])
	if p.ak and not p.ak.x_def().is_empty() and lv == int(p.slot_info("x").get("unlock", -1)):
		news.append("ultimate open (%s)" % Settings.key_cap("hunter_ult"))
	if p.skill_pts > 0:
		news.append("%d point%s to spend" % [p.skill_pts, "s" if p.skill_pts > 1 else ""])
	return ["LEVEL %d" % lv, gains, "  ·  ".join(news)]

## Over your hero, on the world pass: a soft gold column and three chevrons climbing it.
func body(H, cam: Camera3D, p: Hunter) -> void:
	var age := LIFE - t
	if t <= 0.0 or age > BODY or p == null or p.model == null or cam.is_position_behind(p.position):
		return
	var k := age / BODY
	var feet := cam.unproject_position(p.position)
	var a := 1.0 - k
	var c: CanvasItem = H.c
	var gold := HudStyle.GOLD
	var w := COL_W * (0.6 + 0.4 * sin(minf(1.0, k * 3.0) * PI * 0.5))
	for i in 4:      # the column: brightest at the feet, thinning upward
		var h := COL_H * (0.35 + 0.65 * k) * (1.0 - i * 0.22)
		var wi := w * (1.0 - i * 0.2)
		c.draw_rect(Rect2(feet + Vector2(-wi * 0.5, -h), Vector2(wi, h)), Color(gold, 0.14 * a))
	for i in 3:
		var ck := fmod(k * 1.6 + i / 3.0, 1.0)
		var at := feet + Vector2(0, -COL_H * ck)
		var cw := 20.0 + 8.0 * (1.0 - ck)
		var pts := PackedVector2Array([at + Vector2(-cw, cw * 0.55), at, at + Vector2(cw, cw * 0.55)])
		c.draw_polyline(pts, Color(0, 0, 0, 0.5 * a * (1.0 - ck)), 8.0, true)
		c.draw_polyline(pts, Color(gold.lerp(Color.WHITE, 0.3), a * (1.0 - ck)), 5.0, true)

## The card just over the vitals and ability row (at `x0`, its bottom on `y_bottom`).
func card(H, x0: float, y_bottom: float) -> void:
	if t <= 0.0:
		return
	t = maxf(0.0, t - H.get_process_delta_time())
	var age := LIFE - t
	var a := clampf(t / FADE, 0.0, 1.0)
	var pop := 1.0 + 0.25 * (1.0 - clampf(age / POP, 0.0, 1.0))
	var c: CanvasItem = H.c
	var font: Font = HudStyle.BIG
	var news := String(lines[2])
	var w1 := font.get_string_size(String(lines[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var w := 24.0 + maxf(w1, font.get_string_size(news, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var h := 66.0 if news != "" else 48.0
	var r := Rect2(Vector2(x0, y_bottom - CARD_GAP - h), Vector2(maxf(w, 150.0), h))
	H._rounded(r, Color(HudStyle.SHADE, HudStyle.SHADE.a * a), 8)
	c.draw_rect(Rect2(r.position, Vector2(4, h)), Color(HudStyle.GOLD, a))
	HudStyle.text(c, r.position + Vector2(14, 26), String(lines[0]), int(24 * pop), Color(HudStyle.GOLD, a))
	HudStyle.text(c, r.position + Vector2(14, 44), String(lines[1]), 14, Color(HudStyle.INK, a))
	if news != "":
		HudStyle.text(c, r.position + Vector2(14, 61), news, 14, Color(HudStyle.GOLD.lerp(HudStyle.INK, 0.4), a))
