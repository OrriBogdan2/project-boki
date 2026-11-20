class_name GlintSfx
extends RefCounted
## The sounds of Glint Fishing (tools/gen_sfx_glint.py, content/sfx/glint.json, docs/AUDIO.md), all placed at the
## bobber: the cast whip and, a beat later, the plop; a soft water bed on the Ambience bus while you wait; the
## bite tick (the cue to press, bright and loud enough to cut through the garden beds); a reel ratchet loop while
## you hold the line; and a catch sting in the size of the catch. Everything else plays on the SFX bus.
## glint_fishing.gd calls tick() once a frame; `heard` counts each cue so --garden-sfx-check can assert them.

const DB := -4.0                      # dB: the cues, a little above the garden minigames' -6
const BITE_DB := 0.0                  # dB: the bite is the one cue that must be heard over the garden
const BED_DB := -10.0                 # dB: the water bed, dull and quiet
const REEL_DB := -8.0                 # dB: the ratchet
const PLOP_DELAY := 0.3               # s from the whip to the bobber landing
const BED_BUS := "Ambience"
const STATE := GlintFishing.Run.S
const REEL_PITCH := Vector2(0.9, 1.2) # the ratchet's pitch at slack and at full tension

static var heard := {}                # cue name -> times played, for the checks

static func cue(sname: String, pos, vol_db := DB) -> void:
	heard[sname] = int(heard.get(sname, 0)) + 1
	Sfx.play(sname, pos, vol_db, 0.04)

## The catch sting's size: a rare glint is large, an item medium, a snack small.
static func size_of(catch: Dictionary, rare: bool) -> String:
	if rare:
		return "large"
	return "medium" if String(catch["kind"]) == "item" else "small"

## One call a frame after the run stepped: `was` is the state before the step, `was_ears` whether the ears were up,
## `at` where the line meets the water.
static func tick(home, run: GlintFishing.Run, was: STATE, was_ears: bool, at: Vector3) -> void:
	if run.ears() and not was_ears:
		cue("glint_bite", at, BITE_DB)
	if was == STATE.AIM and run.state != STATE.AIM:
		cue("glint_cast", at)
		home.get_tree().create_timer(PLOP_DELAY).timeout.connect(func(): cue("glint_plop", at))
	if was != STATE.SHOW and run.state == STATE.SHOW and run.casts[-1]["how"] == "caught":
		var c: Dictionary = run.casts[-1]
		cue("glint_catch_" + size_of(c["catch"], c["rare"]), at)
	_bed(run.state == STATE.WAIT, at)
	_reel(run.state == STATE.REEL and run.held, run.tension, at)

static func _bed(on: bool, at: Vector3) -> void:
	if on:
		if not Sfx.loop_on("glint_water"):
			heard["glint_water"] = int(heard.get("glint_water", 0)) + 1
		Sfx.loop_hold("glint_water", "glint_water", at, BED_DB, 1.0, BED_BUS)
	else:
		Sfx.loop_stop("glint_water")

static func _reel(on: bool, tension: float, at: Vector3) -> void:
	if on:
		if not Sfx.loop_on("glint_reel"):
			heard["glint_reel"] = int(heard.get("glint_reel", 0)) + 1
		Sfx.loop_hold("glint_reel", "glint_reel", at, REEL_DB, lerpf(REEL_PITCH.x, REEL_PITCH.y, tension))
	else:
		Sfx.loop_stop("glint_reel")

## Fishing ended (or was left): both loops stop.
static func stop() -> void:
	_bed(false, Vector3.ZERO)
	_reel(false, 0.0, Vector3.ZERO)
