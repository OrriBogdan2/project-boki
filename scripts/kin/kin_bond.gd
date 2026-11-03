class_name KinBond
extends RefCounted
## The one place the bond meter (Hunter.ult, 0..1) is filled. Fighting fills it through Bond (hits, combos, the
## passive trickle); a hero's own ultimate fills it through from_ult(), so ult -> Merge is a combo and Merge is never
## locked behind the ult. Owner-side only: a remote hunter's meter comes from its own game.
## Numbers: content/rules/boki_system.json `bond_from_ult` (a share of the bar per kind of ult event).

const FIGHT := "fight"            # the reason Bond uses; no extra blocks and no flash (it is a constant trickle)
const KINDS := ["hit", "knock", "kill"]

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
## event counts (not per target, not additive): a hit then a kill pays the kill's share once. `cast_id` is the kit's
## own id for this cast (required: a new id starts a new cast); what a cast has paid is kept on the hunter.
static func from_ult(h: Hunter, kind: String, cast_id: String) -> float:
	if h == null or h.remote or cast_id == "" or not KINDS.has(kind):
		return 0.0
	var share := float(rules().get(kind, 0.0))
	var c: Dictionary = h.get_meta("bond_cast", {})
	if String(c.get("id", "")) != cast_id:
		c = {"id": cast_id, "got": 0.0}
	var extra := share - float(c["got"])
	if extra <= 0.0:
		return 0.0
	c["got"] = share
	h.set_meta("bond_cast", c)
	return add(h, extra, "ult_" + kind)

static func _flash(h: Hunter, gained: float) -> void:
	if gained <= 0.0 or not h.is_local():
		return
	h.set_meta("bond_flash_at", h.m.time)          # (the bond ring on the Merge box brightens for a moment, GripHud)
	h.m.fx.word(h.pos + Vector3(0, 2.3, 0), "BOND +%d%%" % int(round(gained * 100.0)), Color("ffd23f"))
