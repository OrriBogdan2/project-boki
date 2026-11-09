class_name HealSfx
extends RefCounted
## The sound of sustain, one family (tools/gen_sfx_heal.py): heal_chime (a soft rising chime, louder
## and higher for a bigger heal), shield_gain (a glassy hum), armor_refill (a click and a ring) and
## shield_pop (a shield running out). Every heal, shield and armor gain goes through here, so each
## event is one cue. Heals to one hunter merge into one chime per MERGE seconds. The hunter it
## happens to (the player) hears it in 2D; everyone else's plays at their position.

const MERGE := 0.3                  # s: heals to one hunter within this window share one chime
const HEAL_FULL := 40.0             # hp: a heal this big plays the chime at its fullest
const HEAL_DB := Vector2(-12.0, -3.0)    # dB at the smallest and the fullest heal
const HEAL_PITCH := Vector2(0.92, 1.18)  # pitch scale at the smallest and the fullest heal
const MIN_GAIN := 0.5               # a shield or armor gain smaller than this stays silent
const SHIELD_DB := -5.0
const ARMOR_DB := -4.0
const POP_DB := -7.0

static var cues := {}               # sound name -> times played (--match-audio-check counts cues here)

static func _play(h: Ent, sname: String, db: float, pitch := 1.0) -> void:
	var m: Match = h.m
	cues[sname] = int(cues.get(sname, 0)) + 1
	m.sfx(sname, null if h == m.player else h.pos, db, pitch)

## `gain` hp just went into `h`: one chime now, and what comes in during the next MERGE s as one more.
static func heal(h: Hunter, gain: float) -> void:
	var c: Dictionary = h.heal_cue
	if float(c["t"]) > 0.0:
		c["sum"] = float(c["sum"]) + gain
		return
	c["t"] = MERGE
	_chime(h, gain)

static func _chime(h: Hunter, gain: float) -> void:
	var k := clampf(gain / HEAL_FULL, 0.0, 1.0)
	_play(h, "heal_chime", lerpf(HEAL_DB.x, HEAL_DB.y, k), lerpf(HEAL_PITCH.x, HEAL_PITCH.y, k))

## Every step: the merged heals that came in during a window play as the window closes.
static func tick(h: Hunter, dt: float) -> void:
	var c: Dictionary = h.heal_cue
	if float(c["t"]) <= 0.0:
		return
	c["t"] = float(c["t"]) - dt
	if float(c["t"]) > 0.0:
		return
	if float(c["sum"]) > 0.0:
		c["t"] = MERGE
		_chime(h, float(c["sum"]))
		c["sum"] = 0.0

## `t` (a hunter or a Boki) gains a shield of `amount` (it keeps a bigger one it already has).
static func set_shield(t: Ent, amount: float) -> void:
	var up: bool = amount > float(t.shield) + MIN_GAIN
	t.shield = maxf(float(t.shield), amount)
	if up:
		shield_gain(t)

## The hum for a shield (or a raised aegis) that just grew.
static func shield_gain(t: Ent) -> void:
	_play(t, "shield_gain", SHIELD_DB)

## A shield that ran out by the clock (not one that was broken by hits).
static func shield_end(t: Ent) -> void:
	if float(t.shield) > 0.0:
		_play(t, "shield_pop", POP_DB)

## `h` gains up to `n` armor (never past its max): the click and ring when any of it lands.
static func give_armor(h: Hunter, n: float) -> void:
	var gain := minf(n, h.max_armor - h.armor)
	if gain <= MIN_GAIN:
		return
	h.armor += gain
	_play(h, "armor_refill", ARMOR_DB)
