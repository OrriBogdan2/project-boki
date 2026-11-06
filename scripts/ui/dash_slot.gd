class_name DashSlot
extends RefCounted
## The dash slot: ONE component for the bottom bar in a match (Hud) and at home (HomeDashSlot). It is an
## ordinary ability slot (HudSlot.ab_slot: icon, dark sweep, countdown, red frame, key pill) with a pip
## per charge that fills as the next one recharges, a countdown for that next charge, a flash and a soft
## tick when a charge returns, and a small diamond for the long air dash. Both callers hand it the same
## numbers (src): a match from the Hunter (of_hunter), the farm from its mirror of the same state.

const PIP_R := 5.0                      # px, a charge pip's radius (a round disc, readable at a glance)
const PIP_Y := 18.0                     # px from the slot's bottom edge to the pips' centres (clears the key pill)
const PIP_GAP := 3.0                    # px between pip discs
const RING_W := 2.0                     # px, the recharging pip's progress ring
const AIR_R := 4.5                      # px, the air-dash diamond's half-size
const TICK_VOL := -15.0                 # dB of the charge-returned tick
const TICK_PITCH := 1.9
const TOP_CD_FS := 12                   # countdown size while a charge is ready and another recharges
const AIR_COL := Color("bfe6ff")        # the long air dash, ready

## host instance id -> whole charges last frame (a rise is a charge returning)
static var _was := {}
## host instance id -> what the last draw showed (checks read it):
## {pips: fill per pip, text: countdown, air: 0..1 or -1}
static var shown := {}

## The numbers the slot draws: charges (fractional, the recharging one partly full), the cap, seconds per
## charge, and the air dash's cooldown left and full length (air_max 0 = this dash has no air dash).
static func src(charges: float, cap: int, regen: float, air_cd: float, air_max: float, icon: String,
		col: Color) -> Dictionary:
	return {"charges": charges, "cap": cap, "regen": maxf(0.01, regen), "air_cd": air_cd, "air_max": air_max,
		"icon": icon, "col": col}

static func of_hunter(h: Hunter) -> Dictionary:
	var di := h.slot_info("dash")
	var air_max := air_cd_of(h) if h.ak == null or h.ak.has_long_dash() else 0.0
	return src(h.dashes, int(h.max_dashes()), h.dash_regen(), h.ex_cd, air_max, String(di["icon"]), di["col"])

## How long the air dash takes to come back for this hunter (the kit's dash.air.cd, else its class data).
static func air_cd_of(h: Hunter) -> float:
	var cd: float = h.ak.long_dash_cd() if h.ak else float(h.cdat.get("ex_cd", Hunter.EX_DASH_CD))
	return maxf(0.01, cd)

## The whole charges and the seconds until the next one, from a src.
static func whole(s: Dictionary) -> int:
	return int(floor(float(s["charges"]) + 0.001))

static func next_secs(s: Dictionary) -> float:
	if whole(s) >= int(s["cap"]):
		return 0.0
	return (1.0 - fposmod(float(s["charges"]), 1.0)) * float(s["regen"])

## Draws the slot in `r` on host `H` (Hud or HomeDashSlot). `audible`: tick when a charge returns.
static func draw(H, r: Rect2, s: Dictionary, audible := true) -> void:
	var c: CanvasItem = H.c
	var col: Color = s["col"]
	var n := whole(s)
	var left := next_secs(s)
	var hid: int = H.get_instance_id()
	if _was.has(hid) and n > int(_was[hid]):
		H.ready_flash["dash"] = HudSlot.READY_FLASH
		if audible:
			Sfx.play("click", null, TICK_VOL, 0.0, TICK_PITCH)
	_was[hid] = n
	var key := Settings.key_cap("dash")
	HudSlot.ab_slot(H, "dash", r, String(s["icon"]), key, col, left / float(s["regen"]), left, n >= 1)
	var cap := int(s["cap"])
	var px := r.get_center().x - ((PIP_R * 2.0 + PIP_GAP) * cap - PIP_GAP) * 0.5 + PIP_R
	var fills: Array = []
	for i in cap:
		var fill := clampf(float(s["charges"]) - float(i), 0.0, 1.0)
		_pip(c, Vector2(px + i * (PIP_R * 2.0 + PIP_GAP), r.end.y - PIP_Y), fill, col)
		fills.append(fill)
	shown[hid] = {"pips": fills, "text": "", "air": -1.0}
	if n >= 1 and left > 0.0:
		var t := HudSlot.cd_text(left)
		HudStyle.ctext(c, r.position + Vector2(r.size.x * 0.5, 17.0), t, TOP_CD_FS, Color(HudStyle.INK, 0.9), 4)
		H.slot_text["dash"] = t
	shown[hid]["text"] = String(H.slot_text.get("dash", ""))
	if float(s["air_max"]) > 0.0:
		var back := 1.0 - float(s["air_cd"]) / float(s["air_max"])
		shown[hid]["air"] = clampf(back, 0.0, 1.0)
		_air_mark(c, Vector2(r.end.x - 9.0, r.position.y + 9.0), back)

## One charge: a lit disc when ready, a dark disc with a light ring when spent, the ring filling while it recharges.
static func _pip(c: CanvasItem, at: Vector2, fill: float, col: Color) -> void:
	c.draw_circle(at, PIP_R + 1.0, HudStyle.SHADE_EDGE)
	if fill >= 0.999:
		c.draw_circle(at, PIP_R, col)
		return
	c.draw_circle(at, PIP_R, Color(0.0, 0.0, 0.02, 0.85))
	c.draw_arc(at, PIP_R - RING_W * 0.5, 0.0, TAU, 20, Color(1, 1, 1, 0.3), RING_W)
	if fill > 0.0:
		c.draw_arc(at, PIP_R - RING_W * 0.5, -PI * 0.5, -PI * 0.5 + TAU * fill, 20, col, RING_W)

## The air dash: a diamond, bright once it is back, a growing fill while it recharges.
static func _air_mark(c: CanvasItem, at: Vector2, ready_frac: float) -> void:
	var f := clampf(ready_frac, 0.0, 1.0)
	c.draw_colored_polygon(_diamond(at, AIR_R), HudStyle.SHADE_EDGE)
	var inner := _diamond(at, AIR_R * (0.45 + 0.4 * f))
	c.draw_colored_polygon(inner, AIR_COL if f >= 0.999 else Color(AIR_COL, 0.35 + 0.3 * f))

static func _diamond(at: Vector2, k: float) -> PackedVector2Array:
	return PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k), at + Vector2(-k, 0)])

## The match bar's dash slot: locked until a point is spent (the padlock), else the shared slot with its
## rank pips and the + to spend a point.
static func row_slot(H, r: Rect2, p: Hunter) -> void:
	var s := of_hunter(p)
	var lv := int(p.slot_lv.get("dash", 1))
	if lv <= 0:
		HudSlot.skill_slot(H, "dash", "dash", r, String(s["icon"]), Settings.key_cap("dash"), s["col"], 0.0, 0.0, false)
		return
	draw(H, r, s)
	RankMarks.pips(H, r, "dash", lv, s["col"])
	if p.can_level("dash"):
		RankMarks.plus(H, r, "dash", "dash", Settings.key_cap("dash"))
