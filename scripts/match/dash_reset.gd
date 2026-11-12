class_name DashReset
extends RefCounted
## The takedown refresh (decision 0022): when an ENEMY hunter is knocked or killed, the hunter who gets
## credit and every teammate whose damage or crowd control landed on the victim in the last ASSIST_WINDOW
## get their dash (Shift) back: a one-charge dash refills, a multi-charge dash gains one charge, and the
## long-dash cooldown clears. Only the knocker heals a little. Mobs and bosses don't count, and a hero whose
## dash data says "knock_refresh": false is left out. Match.knock, eliminate and _lose_life call takedown();
## Match.on_damage (and damage-free CC) calls note(). The hero-specific resets (a Sparkle blowout, a Vex
## vault, a knife in a foe) call cue() so every "dash is back" gives the same feedback to the one who got
## it: the reset sound (Sfx.play_reset_cue) and a pop on the HUD's Shift icon.

const HEAL := 0.05          # of max health, per takedown, knocker only (a knock and the kill that follows each give it)
const ASSIST_WINDOW := 4.0  # s: how recent a teammate's hit or CC on the victim must be to count as an assist
const ASSIST_SOFTER_DB := 6.0  # dB: how much quieter an assist's reset cue plays than the knocker's

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
	cue(h, source)
	return true

## The dash came back for `h`: play the cue (softer for an assist) and pop the Shift icon (local hunter only).
static func cue(h: Hunter, source := "hero") -> void:
	if h == null or not h.is_local():
		return
	Sfx.play_reset_cue(Sfx.RESET_CUE_DB - (ASSIST_SOFTER_DB if source == "assist" else 0.0))
	if h.m.hud:
		h.m.hud.ability_feedback("dash", "reset")
	CombatBus.dash_reset_cue.emit(h, source)
