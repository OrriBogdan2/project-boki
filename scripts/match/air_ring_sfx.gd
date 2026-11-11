class_name AirRingSfx
extends RefCounted
## The air rings' sounds (tools/gen_sfx_air_rings.py, content/sfx/air_rings.json, docs/AUDIO.md): a short
## pass-through for a glide ring that steps up a note with each ring of one run along a lane, a rising
## swell for a lift ring, and a quiet hum from the ring nearest you so you can find one by ear. Your own
## passes play at full level; another Hunter's play at its ring, positional and quieter, so you hear
## someone flying a lane on your flank. Passes are pool one-shots (Sfx.play, so the pool's voice limits
## apply to them); the hum is one keyed loop at most.

const PASS := "air_ring_pass"
const LIFT := "air_ring_lift"
const HUM := "air_ring_hum"
const STEPS := [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0]  # pitch of a run's 1st..6th ring: a major pentatonic to the octave
const RUN_GAP_S := 3.0          # s: a lane's next ring within this, flown the same way, is the run's next step
const OTHERS_DB := -6.0         # dB under yours for another Hunter's pass
const HUM_DB := -14.0           # dB: the hum beside a ring (quieter with distance, silent past its reach)
const HUM_LIFT_PITCH := 0.75    # a lift ring hums a fourth under a glide ring

## One hunter's run along a lane: which way it flies, how many rings so far, when it took the last one.
class Run:
	var lane := -1
	var way := 0.0              # the sign of its flight along the lane's direction
	var step := 0
	var last_t := 0.0           # match time (s)

var _m: Match
var _runs := {}                 # Hunter nid -> Run

func _init(m: Match) -> void:
	_m = m
	Sfx.ensure(HUM)             # Sfx.loop_start doesn't load a file on first use as play does (docs/DEBT.md)

## A hunter went through a ring. AirRings calls it for the hunters this game moves as the ring throws them,
## and for the ones another game moves as they pass (here only the sound plays).
func passed(h: Hunter, rg: Dictionary) -> void:
	var own := h == _m.player
	var at: Variant = null if own else rg["pos"]
	var vol := 0.0 if own else OTHERS_DB
	if rg["lift"]:
		_runs.erase(h.nid)
		Sfx.play(LIFT, at, vol)
	else:
		Sfx.play(PASS, at, vol, 0.0, STEPS[_step(h, rg)])

## Which ring of its run this is: the next step after a ring of the same lane, flown the same way, at most
## RUN_GAP_S ago; otherwise the first.
func _step(h: Hunter, rg: Dictionary) -> int:
	var v := h.net_vel if h.remote else h.vel
	var way := signf(Vector2(v.x, v.z).dot(rg["dir"]))
	var run: Run = _runs.get(h.nid)
	if run == null:
		run = Run.new()
		_runs[h.nid] = run
	var goes_on := run.lane == int(rg["lane"]) and run.way == way and _m.time - run.last_t <= RUN_GAP_S
	run.step = mini(run.step + 1, STEPS.size() - 1) if goes_on else 0
	run.lane = int(rg["lane"])
	run.way = way
	run.last_t = _m.time
	return run.step

## Every step: the hum of the ring nearest you, while one is within the hum's reach.
func tick(rings: Array) -> void:
	var p: Hunter = _m.player
	if p == null or p.out:
		return
	var best := float(Sfx.sound_reach.get(HUM, 0.0))
	var near: Dictionary = {}
	for rg in rings:
		var d := p.pos.distance_to(rg["pos"])
		if d < best:
			best = d
			near = rg
	if not near.is_empty():
		Sfx.loop_hold(HUM, HUM, near["pos"], HUM_DB, HUM_LIFT_PITCH if near["lift"] else 1.0)
