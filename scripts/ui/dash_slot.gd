class_name DashSlot
extends RefCounted
## The dash slot: ONE component for the bottom bar in a match (Hud) and at home (HomeDashSlot). It is an
## ordinary ability slot (HudSlot.ab_slot: icon, dark sweep, countdown, red frame, key pill) with, for a
## dash of 2+ charges, a disc per charge on the top edge (HudSlot.charge_discs) that fills as the next one
## recharges, a countdown for that next charge, a flash and a soft tick when a charge returns, and a small
## diamond for the long air dash. Both callers hand it the same numbers (src): a match from the Hunter
## (of_hunter), the farm from its mirror of the same state.

const PIP_Y := 16.0                     # px from the slot's bottom edge to the rank pips (clears the key pill)
const AIR_R := 4.5                      # px, the air-dash diamond's half-size
const TICK_VOL := -15.0                 # dB of the charge-returned tick
const TICK_PITCH := 1.9
const AIR_CD_FS := 10                   # the air dash's countdown while airborne
const AIR_COL := Color("bfe6ff")        # the long air dash, ready

## host instance id -> whole charges last frame (a rise is a charge returning)
static var _was := {}
## host instance id -> what the last draw showed (checks read it):
## {pips: fill per pip, text: countdown, air: 0..1 or -1}
static var shown := {}

## The numbers the slot draws: charges (fractional, the recharging one partly full), the cap, seconds per
## charge, and the air dash's cooldown left and full length (air_max 0 = this dash has no air dash).
static func src(charges: float, cap: int, regen: float, air_cd: float, air_max: float, icon: String,
		col: Color, airborne := false) -> Dictionary:
	return {"charges": charges, "cap": cap, "regen": maxf(0.01, regen), "air_cd": air_cd, "air_max": air_max,
		"icon": icon, "col": col, "airborne": airborne}

static func of_hunter(h: Hunter) -> Dictionary:
	var di := h.slot_info("dash")
	var air_max := air_cd_of(h) if h.ak == null or h.ak.has_long_dash() else 0.0
	return src(h.dashes, int(h.max_dashes()), h.dash_regen(), h.ex_cd, air_max, String(di["icon"]), di["col"],
		not h.grounded)

## How long the air dash takes to come back for this hunter (the kit's dash.air.cd, else its class data).
static func air_cd_of(h: Hunter) -> float:
	var cd: float = h.ak.long_dash_cd() if h.ak else DashState.long_cd(h.cdat)
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
	var cap := int(s["cap"])
	HudSlot.shown_pips.erase("dash")
	HudSlot.ab_slot(H, "dash", r, String(s["icon"]), key, col, left / float(s["regen"]), left, n >= 1,
		float(s["charges"]), cap)
	var text := String(H.slot_text.get("dash", ""))
	shown[hid] = {"pips": HudSlot.shown_pips.get("dash", []), "text": text, "air": -1.0}
	if float(s["air_max"]) > 0.0:
		var back := 1.0 - float(s["air_cd"]) / float(s["air_max"])
		shown[hid]["air"] = clampf(back, 0.0, 1.0)
		_air_mark(c, Vector2(r.end.x - 9.0, r.position.y + 9.0), back)
		shown[hid]["air_text"] = ""
		if bool(s["airborne"]) and float(s["air_cd"]) > 0.0:
			var at := HudSlot.cd_text(float(s["air_cd"]))      # in the air the pounce's own timer is spelled out
			HudStyle.ctext(c, Vector2(r.end.x - 9.0, r.position.y + 28.0), at, AIR_CD_FS, Color(AIR_COL, 0.95), 4)
			shown[hid]["air_text"] = at

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
