extends RefCounted
## --sfx-set-check section 11: Sparkle's Kitefall has a cue on every beat (crouch, lift-off, hover, drop, strike).
## One cast runs frame by frame; each cue must sound within CUE_MS of its state change (counted in sim time, so the
## number does not depend on how fast the check runs), and the hover's hum loop must be off again by the drop.

const DT := 1.0 / 60.0
const CUE_MS := 50.0           # ms: the longest a beat may wait for its cue
const MAX_FRAMES := 240         # frames: well past the 2.5 s the cast takes
const NEVER := 1 << 20         # frame: stands for a cue that did not sound
const BEATS := [["crouch", "vv_ult_charge"], ["rise", "vv_ult_rise"], ["fall", "vv_ult_crack"],
		["after", "vv_ult_slam"]]

func run(main: Node, ok: Callable) -> void:
	Save.no_write = true
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("mage", 6.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var U: MageUlt = (P.ak as MageKit).ult
	Sfx.listener = P.pos           # (the match only moves it while it draws)
	Sfx.last_played.clear()
	var started := HunterKeys.ult_pressed(P)
	var seen := {}                       # beat or "hum_on"/"hum_off" -> the frame it happened
	var cue_at := {}                     # sound -> the frame it first sounded
	var frame := 0
	while frame < MAX_FRAMES and U.phase() != "after":
		_note(U, frame, seen, cue_at)
		ac.step(m, DT)
		frame += 1
	_note(U, frame, seen, cue_at)
	ok.call(started and seen.has("crouch"), "Kitefall: the press starts the cast")
	for b in BEATS:
		var ms := _ms(cue_at.get(b[1], NEVER), seen.get(b[0], 0))
		ok.call(ms >= 0.0 and ms <= CUE_MS, "Kitefall %s: %s sounds %.0f ms after the state change" % [b[0], b[1], ms])
	var on := _ms(seen.get("hum_on", NEVER), seen.get("air", 0))
	ok.call(on >= 0.0 and on <= CUE_MS, "Kitefall hover: the hum loop is on %.0f ms after the hover starts" % on)
	var off := _ms(seen.get("hum_off", NEVER), seen.get("fall", 0))
	ok.call(off >= 0.0 and off <= CUE_MS, "Kitefall drop: the hum loop is off %.0f ms after the drop starts" % off)
	m.queue_free()

## Milliseconds from the frame a state began to the frame its cue sounded (huge when the cue never did).
func _ms(cue_frame: int, state_frame: int) -> float:
	return (cue_frame - state_frame) * DT * 1000.0

## Records the frame each beat starts and each cue first sounds.
func _note(U: MageUlt, frame: int, seen: Dictionary, cue_at: Dictionary) -> void:
	var ph := U.phase()
	if ph != "" and not seen.has(ph):
		seen[ph] = frame
	for b in BEATS:
		if Sfx.last_played.has(b[1]) and not cue_at.has(b[1]):
			cue_at[b[1]] = frame
	var hum := Sfx.loop_on(U.hum_key())
	if hum and not seen.has("hum_on"):
		seen["hum_on"] = frame
	if seen.has("hum_on") and not hum and not seen.has("hum_off"):
		seen["hum_off"] = frame
