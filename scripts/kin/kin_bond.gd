class_name KinBond
extends RefCounted
## The one place the bond meter (Hunter.ult, 0..1) is written to fill it. Fighting fills it through Bond (hits, combos,
## the passive trickle); a hero's own ultimate fills it through from_ult(), so ult -> Merge is a combo and Merge is never
## locked behind the ult (fighting alone still fills the bar). Owner-side only: a remote hunter's meter comes from its game.
## Numbers: content/rules/boki_system.json `bond_from_ult` (a share of the bar per kind of ult event).

const FIGHT := "fight"            # the reason Bond uses; no extra blocks and no flash (it is a constant trickle)
const KINDS := ["hit", "knock", "kill"]

static var _casts := {}            # hunter instance id -> {id, got}: what one cast has already paid into the bar

static func rules() -> Dictionary:
	return Content.rules("boki_system").get("bond_from_ult", {})

## Adds `amount` (a share of the bar, clamped to a full bar). `reason` is "fight" (Bond, keeps today's rules) or
## anything else ("ult_hit", ...): those are also blocked while merged (the bar is spent) and while the Boki cannot
## fight (downed, resting, away), like normal fill. Returns the share actually added.
static func add(h: Hunter, amount: float, reason: String) -> float:
	if h == null or not is_instance_valid(h) or h.out or h.remote or amount <= 0.0 or h.ult >= 1.0:
		return 0.0
	if reason != FIGHT and (KinMerge.active(h) or h.downed or not h.has_kin_ready()):
		return 0.0
	var was := h.ult
	h.ult = minf(1.0, h.ult + amount)
	var gained := h.ult - was
	if reason != FIGHT:
		_flash(h, gained)
	if was < 1.0 and h.ult >= 1.0:
		h.m.on_bond_ready(h)
	if reason != FIGHT:
		CombatBus.bond_gained.emit(h, gained, reason)
	return gained

## A kit calls this when its ultimate hits / knocks / kills (kind = "hit", "knock", "kill"). Per cast only the best
## event counts (not per target, not additive): a hit then a kill pays the kill's share once. `cast_id` identifies the
## cast; kits that have none leave it empty and the hunter's last cast time is used.
static func from_ult(h: Hunter, kind: String, cast_id := "") -> float:
	if h == null or not KINDS.has(kind):
		return 0.0
	var share := float(rules().get(kind, 0.0))
	var id := cast_id if cast_id != "" else "t%.3f" % h.cast_at
	var key := h.get_instance_id()
	var c: Dictionary = _casts.get(key, {})
	if String(c.get("id", "")) != id:
		c = {"id": id, "got": 0.0}
	var extra := share - float(c["got"])
	if extra <= 0.0:
		_casts[key] = c
		return 0.0
	c["got"] = share
	_casts[key] = c
	return add(h, extra, "ult_" + kind)

## Forget the per-cast bookkeeping (a new match / a check).
static func reset() -> void:
	_casts.clear()

static func _flash(h: Hunter, gained: float) -> void:
	if gained <= 0.0 or not h.is_local():
		return
	h.set_meta("bond_flash_at", h.m.time)          # (the bond ring in the Boki HUD brightens for a moment, BokiHud)
	h.m.fx.word(h.pos + Vector3(0, 2.3, 0), "BOND +%d%%" % int(round(gained * 100.0)), Color("ffd23f"))
