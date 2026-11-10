class_name DashReset
extends RefCounted
## The takedown reset: a hunter who gets credit for knocking or killing an ENEMY hunter has their dash
## (Shift) back at once, every charge and the long-dash cooldown, and heals a little. Mobs and bosses
## don't count. Match.knock, eliminate and _lose_life call takedown(); the hero-specific resets (a
## Sparkle blowout, a Vex vault, a knife in a foe) call cue() so every "dash is back" gives the same
## feedback to the one who got it: the reset sound (Sfx.play_reset_cue) and a pop on the HUD's Shift icon.

const HEAL := 0.05          # of max health, per takedown (a knock and the kill that follows each give it)

## `h` earned a takedown on enemy hunter `victim`. Does nothing for a hunter who is down or out.
static func takedown(h: Hunter, victim: Hunter) -> void:
	if h == null or victim == null or h == victim or h.team == victim.team or h.downed or h.out:
		return
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	h.heal(h.max_hp * HEAL)
	cue(h, "takedown")

## The dash came back for `h` by some other means: play the cue and pop the Shift icon (local hunter only).
static func cue(h: Hunter, source := "hero") -> void:
	if h == null or not h.is_local():
		return
	Sfx.play_reset_cue()
	if h.m.hud:
		h.m.hud.ability_feedback("dash", "reset")
	CombatBus.dash_reset_cue.emit(h, source)
