class_name DashReset
extends RefCounted
## The takedown refresh (decision 0022): when an ENEMY hunter is knocked or killed, the hunter who gets
## credit and every teammate whose damage or crowd control landed on the victim in the last ASSIST_WINDOW
## get their dash (Shift) back: a one-charge dash refills, a multi-charge dash gains one charge, and the
## long-dash cooldown clears. Only the knocker heals a little. Mobs and bosses don't count, and a hero whose
## dash data says "knock_refresh": false is left out. Match.knock, eliminate and _lose_life call takedown();
## Match.on_damage (and damage-free CC) calls note(). The feedback is ResetCue's, the same as every
## hero-specific reset: path "takedown" for the knocker, "assist" (softer) for a teammate.

const HEAL := 0.05          # of max health, per takedown, knocker only (a knock and the kill that follows each give it)
const ASSIST_WINDOW := 4.0  # s: how recent a teammate's hit or CC on the victim must be to count as an assist

## Hunter `by` (or its Boki) landed damage or crowd control on enemy hunter `target`: remember when.
## One dictionary write per landed hit; takedown() reads it.
static func note(target: Ent, by: Ent) -> void:
	var cred: Ent = by.owner_h if by is Kin and by.owner_h else by
	if target is Hunter and cred is Hunter and cred.team != target.team:
		target.hit_by[cred.get_instance_id()] = float(target.m.time)

## `h` earned a takedown on enemy hunter `victim`: refresh `h` and the teammates who assisted.
static func takedown(h: Hunter, victim: Hunter) -> void:
	if h == null or victim == null or h == victim or h.team == victim.team:
		return
	if _refresh(h, "takedown"):
		h.heal(h.max_hp * HEAL)
	for mate in h.m.hunters:
		var at = victim.hit_by.get(mate.get_instance_id())
		if mate != h and mate.team == h.team and at != null and float(h.m.time) - float(at) <= ASSIST_WINDOW:
			_refresh(mate, "assist")

## Gives `h` its dash back by the rule above; false if it can't have it (down, out, another game's, opted out).
static func _refresh(h: Hunter, source: String) -> bool:
	if h.downed or h.out or h.remote or (h.ak and not bool(h.ak.dash_def().get("knock_refresh", true))):
		return false
	var most := h.max_dashes()
	h.dashes = most if most <= 1.0 else minf(most, h.dashes + 1.0)
	h.ex_cd = 0.0
	ResetCue.play(h, source)
	return true
