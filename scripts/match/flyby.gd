class_name Flyby
extends RefCounted
## A rival's shot that misses you by a little still sounds: one short whoosh as it passes within REACH
## metres of the local Hunter, by the shot's family and pitched by its speed (cues: tools/gen_flyby_sfx.py).
## Never for your own or your team's shots, and at most MAX_CUES in any WINDOW seconds. One cue per shot.
## The family is read from what a remote shot also carries (colour, speed, size), so online shots sound the same.

const REACH := 2.0           # m: a rival shot this close to your chest sounds
const CHEST := 0.9           # m above your feet
const WINDOW := 0.2          # s
const MAX_CUES := 3          # per WINDOW
const VOL_DB := -3.0
const SPEED_SLOW := 15.0     # m/s and under: the lowest pitch
const SPEED_FAST := 75.0     # m/s and over: the highest pitch
const PITCH_SLOW := 0.85
const PITCH_FAST := 1.4
const ORB_SIZE := 0.4        # shot radius: a big glowing ball
const COOL_MAX_SPEED := 40.0 # m/s: cold-coloured shots slower than this are ice (faster ones are bullets)
const BOLT_SIZE := 0.16      # radius above this is a bolt or arrow, at or under it a bullet
const ARROW_SPEED := 50.0

var heard: Array[float] = []     # match times of the cues played inside the window
var last_family := ""            # the family of the latest cue (--flyby-check)
var played := 0                  # cues played this match (--flyby-check)

static func family(s: Dictionary) -> String:
	var x: Dictionary = s["x"]
	var col: Color = s["col"]
	var r: float = s["r"]
	var speed := (s["vel"] as Vector2).length()
	var warm := (col.h < 0.12 or col.h > 0.95) and col.s > 0.5
	if x.has("lob"): return "rock"
	if x.get("deco", "") == "orb" or r >= ORB_SIZE: return "orb"
	if col.h > 0.45 and col.h < 0.65 and speed < COOL_MAX_SPEED: return "ice"
	if warm and r < 0.3: return "fire"
	if speed >= ARROW_SPEED and r > BOLT_SIZE: return "arrow"
	return "bullet" if r <= BOLT_SIZE else "bolt"

static func pitch_of(speed: float) -> float:
	return clampf(remap(speed, SPEED_SLOW, SPEED_FAST, PITCH_SLOW, PITCH_FAST), PITCH_SLOW, PITCH_FAST)

## Called once per sim step after the shots moved.
func tick(m: Match) -> void:
	var h := m.player
	if h == null or h.dead or h.downed:
		return
	var chest := h.pos + Vector3(0, CHEST, 0)
	for s in m.shots:
		if s.has("fb") or int(s["team"]) == h.team:
			continue
		var x: Dictionary = s["x"]
		if x.get("melee", false) or x.get("cos", false):
			continue
		var near := Geometry3D.get_closest_point_to_segment(chest, s["prev"], s["pos"])
		if near.distance_to(chest) <= REACH:
			s["fb"] = true
			_cue(m, s, near)

func _cue(m: Match, s: Dictionary, at: Vector3) -> void:
	while not heard.is_empty() and m.time - heard[0] > WINDOW:
		heard.pop_front()
	if heard.size() >= MAX_CUES:
		return
	heard.append(m.time)
	last_family = family(s)
	played += 1
	Sfx.play("flyby_" + last_family, at, VOL_DB, 0.04, pitch_of((s["vel"] as Vector2).length()))
