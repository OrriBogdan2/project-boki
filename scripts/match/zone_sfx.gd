class_name ZoneSfx
extends RefCounted
## The closing zone's sounds (tools/gen_sfx_zone.py, content/sfx/zone.json; docs/AUDIO.md). ShrinkZone owns one
## and drives it from the match clock and this game's own player, so every game hears its own and nothing goes
## over Net:
##   warn   zone_warn   once before each close (ShrinkZone._warn, warn_s ahead), flat, the score ducked under it.
##                      One sting, never a countdown: the Ways Out ticks (HeartSfx) stay the only countdown.
##   wall   zone_hum    a held loop on the edge's nearest point to you, from either side; Sfx's distance
##                      roll-off makes it grow as you near the wall
##   cross  zone_cross  flat, as you pass the edge: lower going out, brighter coming back in
##   tick   zone_tick   flat, each time the zone's damage lands on you. Match.on_damage plays no hurt voice for
##                      it, so a zone tick never sounds like a hit taken
## No words anywhere (the kin and the feed say what happens), so a solo hears nothing about a squad.

const HUM_KEY := "zone_hum"
const HUM_DB := 0.0
const WARN_DB := -2.0
const DUCK_WARN := Vector2(1.5, -6.0)   # seconds held, dB: the score under the warning
const CROSS_DB := -4.0
const OUT_PITCH := 0.82                 # the crossing going out: lower, darker
const IN_PITCH := 1.15                  # ... and coming back in: brighter
const TICK_DB := -6.0
const EDGE_PAD := 0.6                   # m past the edge before a crossing counts, so standing on it is quiet

var cues: Array = []                    # every one-shot cue in order ("warn", "out", "in", "tick"), for the check
var _z: ShrinkZone
var _out := false                       # the player's side of the edge at the last crossing
var _side_known := false                # whether _out is known (not after you are out of the match)

func _init(zone: ShrinkZone) -> void:
	_z = zone

## A close starts in warn_s.
func warn() -> void:
	_cue("warn", "zone_warn", WARN_DB)
	Sfx.duck(DUCK_WARN.x, DUCK_WARN.y)

## The zone's damage landed on this game's player.
func tick() -> void:
	_cue("tick", "zone_tick", TICK_DB)

## Each match tick: the hum on the wall and the crossings.
func update() -> void:
	var p := _z.m.player
	if p == null or p.out or p.extracted:
		_side_known = false
		return
	var off := Vector2(p.pos.x, p.pos.z) - _z.cur_c
	var dist := off.length()
	var wall := _z.cur_c + (off / dist if dist > 0.01 else Vector2.RIGHT) * _z.cur_r
	Sfx.loop_hold(HUM_KEY, "zone_hum", Vector3(wall.x, p.pos.y, wall.y), HUM_DB)
	var past := dist - _z.cur_r
	if not _side_known:
		_side_known = true
		_out = past > 0.0
	elif _out and past < -EDGE_PAD:
		_out = false
		_cue("in", "zone_cross", CROSS_DB, IN_PITCH)
	elif not _out and past > EDGE_PAD:
		_out = true
		_cue("out", "zone_cross", CROSS_DB, OUT_PITCH)

func _cue(what: String, sname: String, db: float, pitch := 1.0) -> void:
	cues.append(what)
	Sfx.play(sname, null, db, 0.05, pitch)
