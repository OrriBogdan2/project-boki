class_name DashReset
extends RefCounted
## The takedown reset: a hunter who gets credit for knocking or killing an ENEMY hunter has their dash
## (Shift) back at once and heals a little; a teammate who hit that hunter in the last few seconds (an
## assist, ArchKit._tick_knocks) gets the dash back with no heal. A one-charge dash comes back whole; a
## dash with charges gets one charge (the source: "hunters with multiple dashes only get 1 charge back on
## knock"; owner item 159: every hero, assists count). Mobs and bosses don't count. Match.knock, eliminate
## and _lose_life call takedown(); the hero-specific resets (a Sparkle blowout, a Vex vault, a knife in a
## foe) call cue() so every "dash is back" gives the same feedback to the one who got it: the reset sound
## (Sfx.play_reset_cue) and a pop on the HUD's Shift icon.

const HEAL := 0.05          # of max health, per takedown (a knock and the kill that follows each give it)

## `h` earned a takedown on enemy hunter `victim`. Does nothing for a hunter who is down or out.
static func takedown(h: Hunter, victim: Hunter) -> void:
	if not _earns(h, victim):
		return
	refresh(h)
	h.heal(h.max_hp * HEAL)
	cue(h, "takedown")

## `h` hit enemy hunter `victim` shortly before a teammate knocked them: the dash comes back, no heal.
static func assist(h: Hunter, victim: Hunter) -> void:
	if not _earns(h, victim):
		return
	refresh(h)
	cue(h, "assist")

## The dash back: a one-charge dash whole, a dash with charges one charge; the long-dash cooldown cleared.
static func refresh(h: Hunter) -> void:
	var most := h.max_dashes()
	h.dashes = most if most <= 1.0 else minf(most, h.dashes + 1.0)
	h.ex_cd = 0.0

static func _earns(h: Hunter, victim: Hunter) -> bool:
	return h != null and victim != null and h != victim and h.team != victim.team and not h.downed and not h.out

## The dash came back for `h` by some other means: play the cue and pop the Shift icon (local hunter only).
static func cue(h: Hunter, source := "hero") -> void:
	if h == null or not h.is_local():
		return
	Sfx.play_reset_cue()
	if h.m.hud:
		h.m.hud.ability_feedback("dash", "reset")
	CombatBus.dash_reset_cue.emit(h, source)
