class_name HunterUltTile
extends RefCounted
## The hero's own ultimate (R, HeroUlt) on the ability row beside Shift and E, in the hero's ability colour and
## the same slot art as the rest of the row (HudSlot), one look for every hero. States (`state`, checks read it):
##   locked   a padlock and the level it opens at
##   cooling  the dimmed icon, the cooldown sweep and countdown
##   blocked  off cooldown but it can't be cast now (stunned, downed, merged...): the dim icon under a padlock
##   ready    a lit frame (HudSlot.lit), steady; the moment it comes back from cooling or the level lock, a short
##            shine crosses it (SHINE_T)
## The key cap is "hunter_ult"'s; hover id "x".

const SHINE_T := 0.6        # s: the light crossing the tile when the ultimate comes back

static var state := ""          # what the tile drew last (see above; "" before the first draw)
static var shine_from := -INF   # match time the last shine started
static var _host_id := 0        # the HUD those two belong to: a new HUD starts quiet, no shine

## Draws the tile at (x, y) for a hero with an R and returns the x after it (x unchanged without one).
static func draw(H, p: Hunter, x: float, y: float, s: float, gap: float) -> float:
	if p.ak == null or p.ak.x_def().is_empty():
		return x
	var xi := p.slot_info("x")
	var r := Rect2(Vector2(x, y), Vector2(s, s))
	var key := Settings.key_cap("hunter_ult")
	_track(H, _state_of(xi), float(H.m.time))
	if state == "locked":
		H.hover_spots.append([r, "x"])
		HudSlot.locked(H, "x", r, String(xi["icon"]), xi["col"], key, false, "LV %d" % int(xi["unlock"]))
		HudSlot.deny_pulse(H, "x", r)
		return x + s + gap
	var cd_left := float(xi["cd"])
	var frac := cd_left / maxf(0.01, float(xi["cd_max"])) if cd_left > 0.0 else 0.0
	H._ab_slot("x", r, String(xi["icon"]), key, xi["col"], frac, cd_left, state == "ready")
	if state == "ready":
		HudSlot.lit(H, r, xi["col"], String(xi["icon"]), shine(float(H.m.time)))
	elif state == "blocked":
		HudSlot.lock_over(H, r)
	RecastCue.slot(H, p, "x", r)          # X again in the ult (an early landing, the late crack)
	return x + s + gap

## How much of the shine is left at match time `now`: 1 the moment the ultimate came back, 0 once it's steady.
static func shine(now: float) -> float:
	return clampf(1.0 - (now - shine_from) / SHINE_T, 0.0, 1.0)

static func _state_of(xi: Dictionary) -> String:
	if bool(xi["locked"]):
		return "locked"
	if float(xi["cd"]) > 0.0:
		return "cooling"
	return "blocked" if bool(xi["blocked"]) else "ready"

## Moves `state` on; coming back to ready from cooling or the level lock starts the shine (out of a stun it
## just goes steady again).
static func _track(H, now_state: String, now: float) -> void:
	if H.get_instance_id() != _host_id:
		_host_id = H.get_instance_id()
		state = ""
		shine_from = -INF
	if now_state == "ready" and state in ["cooling", "locked"]:
		shine_from = now
	state = now_state

## The hover text: [title, colour] then rows of [text, colour, size].
static func tip(p: Hunter) -> Array:
	if p.ak == null or p.ak.x_def().is_empty():
		return []
	var xi := p.slot_info("x")
	var out: Array = [[String(xi["name"]), xi["col"]]]
	out.append(["%s ultimate  ·  %s" % [Arch.name_of(p.arch), Settings.key_cap("hunter_ult")], HudStyle.MUTED, 12])
	out.append([String(xi["desc"]), HudStyle.INK, 13])
	var when := "ready"
	if bool(xi["locked"]):
		when = "unlocks at level %d" % int(xi["unlock"])
	elif float(xi["cd"]) > 0.0:
		when = "ready in %ss" % KinText.n(ceilf(float(xi["cd"])))
	elif bool(xi["blocked"]):
		when = "can't be cast right now"
	out.append(["Cooldown %ss  ·  %s" % [KinText.n(float(xi["cd_max"])), when], HudStyle.MUTED, 13])
	return out
