class_name LevelPop
extends RefCounted
## The level-up pop: a banner under the top of the screen that says which level you reached and what
## got better (the weapon step on even levels; odd levels get a toast, see Hud.level_up). It fades after a few
## seconds. State lives on the Hud as `lvl_note` ({lvl, info, t0}).

const HOLD := 3.4         # seconds on screen, fades included
const FADE_IN := 0.18
const FADE_OUT := 0.6

static func start(hud, lvl: int, info: Dictionary) -> void:
	hud.lvl_note = {"lvl": lvl, "info": info, "t0": hud.m.time}

static func draw(hud, sz: Vector2) -> void:
	var n: Dictionary = hud.lvl_note
	if n.is_empty():
		return
	var t: float = hud.m.time - float(n["t0"])
	if t < 0.0 or t > HOLD:
		if t > HOLD: hud.lvl_note = {}
		return
	var a := clampf(t / FADE_IN, 0.0, 1.0) * clampf((HOLD - t) / FADE_OUT, 0.0, 1.0)
	var gold := Color("ffd27a")
	var info: Dictionary = n["info"]
	var lvl := int(n["lvl"])
	var w := 400.0
	var h := 96.0 if not info.is_empty() else 64.0
	var pop := 1.0 + 0.08 * maxf(0.0, 1.0 - t / 0.3)
	var r := Rect2(Vector2(sz.x * 0.5 - w * 0.5 * pop, sz.y * 0.14), Vector2(w * pop, h * pop))
	hud._rounded(r, Color(0.05, 0.06, 0.1, 0.92 * a), 14, Color(gold, 0.9 * a), 2)
	var cx := r.get_center().x
	hud._ctext(Vector2(cx, r.position.y + 28), "LEVEL %d" % lvl, 26, Color(gold, a), hud.big)
	var sub := "+1 skill point"
	if lvl == int(Hunter.ULT_AT[0]): sub += "  ·  your ultimate is ready to unlock"
	if info.is_empty():
		hud._ctext(Vector2(cx, r.position.y + 52), sub, 14, Color(hud.MUTED, a))
		return
	var col: Color = info["col"]
	var y := r.position.y + 54
	Icons.draw(hud.c, String(info["icon"]), Vector2(r.position.x + 34, y + 2), 12.0, Color(col, a))
	var nm := "%s%s" % [info["name"], "  x%d" % int(info["n"]) if int(info["n"]) > 1 else ""]
	hud._text(Vector2(r.position.x + 56, y - 2), "Weapon: " + nm, 17, Color(col, a), hud.big)
	hud._text(Vector2(r.position.x + 56, y + 16), String(info["desc"]), 13, Color(hud.INK, 0.85 * a))
	hud._text(Vector2(r.end.x - 164, r.end.y - 9), sub, 11, Color(hud.MUTED, a), null, HORIZONTAL_ALIGNMENT_RIGHT, 150.0)
