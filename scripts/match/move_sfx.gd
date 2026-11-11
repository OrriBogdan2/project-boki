class_name MoveSfx
extends RefCounted
## A Hunter's footsteps and landings, heard as in the source: placed where they happen (Sfx pans them),
## fading with distance, another Hunter's footsteps out to step_reach_m, and weighted by the Hunter's
## height (content/rules/move_sfx.json): tall Kael lands lower and louder than small Neve. Silent while
## sneaking (crouched) or unseen.

const STEP_DB := -13.0         # dB: your own footstep
const OTHER_STEP_DB := -17.0   # dB: anyone else's, before the distance falloff

static func rules() -> Dictionary:
	return Content.rules("move_sfx")

## (pitch, dB) for an archetype's weight: 1.0 and 0 dB at the reference height (and for one not listed).
static func weight(arch: String) -> Vector2:
	var r := rules()
	var d := float((r["height_m"] as Dictionary).get(arch, r["ref_height_m"])) - float(r["ref_height_m"])
	var pitch := clampf(1.0 - d * float(r["pitch_per_m"]), float(r["pitch_min"]), float(r["pitch_max"]))
	return Vector2(pitch, clampf(d * float(r["db_per_m"]), -float(r["db_max"]), float(r["db_max"])))

## A footstep while running (Hunter render, with its dust puff): what it sounds like depends on what's
## underfoot (planks, paved paths and stairs, snow, or grass and earth).
static func footstep(h: Hunter) -> void:
	var m: Match = h.m
	if m == null or m.world == null or h.unseen or h.crouch:
		return
	var w: World = m.world
	var ix := int(floorf(h.pos.x))
	var iz := int(floorf(h.pos.z))
	if not w.inb(ix, iz):
		return
	var i := w.idx(ix, iz)
	var surf := "grass"
	if w.bridge.has(i): surf = "wood"
	elif w.stairs.has(i) or w.paint.has(i) or w.kind[i] != World.T_GROUND: surf = "stone"
	elif w.style_at(i) == "frost": surf = "snow"
	var wt := weight(h.arch)
	var vol := (STEP_DB if h == m.player else OTHER_STEP_DB) + wt.y
	Sfx.play(HeroSfx.of(h, "step_" + surf, "step_" + surf), h.pos, vol, 0.08, wt.x, float(rules()["step_reach_m"]))

## A landing's thud at `vol_db` (before the weight).
static func land(h: Hunter, vol_db: float) -> void:
	var wt := weight(h.arch)
	h.m.sfx("land", h.pos, vol_db + wt.y, wt.x)
