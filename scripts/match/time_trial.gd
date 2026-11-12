class_name TimeTrial
extends RefCounted
## The Training Grounds' time trial (the --arena map's "grounds" -> "trial" block): ten gates on the open
## floor west of the Training Room, between a start arch and a finish arch. The clock starts as you leave
## the start arch, the gates count only in order (a dash gate only while you dash), and the finish arch
## stops it. The course asks for a dash, a wall kick up a four-terrace tower, a jump pad onto a taller one
## and a glide back down. Each Hunter keeps a personal best in the save (Save.d["time_trial"]).
## Props are the game's own: air rings for the gates, the lair gate's posts and lintel for the arches.

const GATE_R := 1.6           # [m] the body's middle this close to a gate's middle is through it (as an air ring)
const BODY_UP := 0.8          # [m] from the feet to the body's middle (as Match._update_rings)
const ARCH_R := 2.0           # [m] flat distance from an arch's middle that counts as under it
const ARCH_H := 3.5           # [m] and no higher above its foot than this
const ARCH_W := 3.5           # [m] the arch's opening
const PAD_R := 0.8            # [m] how close to the pad's middle you step to be thrown (as Match._update_pads)
const MOVE_TAG := {"dash": "DASH", "kick": "WALL KICK", "pad": "JUMP PAD", "glide": "GLIDE"}
const NEXT_COL := Color("ffd25a")       # the gate you go through next
const ARCH_COL := Color("8fe3c8")

## One gate: where its middle is, the move it asks for ("" none), its ring mesh.
class Gate:
	var at := Vector3.ZERO
	var move := ""
	var node: Node3D = null
	var ring: MeshInstance3D = null

var m: Match
var gates: Array[Gate] = []
var start := Vector3.INF
var finish := Vector3.INF
var pad_at := Vector3.INF
var pad_land := Vector3.INF
var running := false
var run_t := 0.0              # [s] on the clock
var next_i := 0               # the gate you go through next (gates.size(): on to the finish)
var run_arch := ""            # the Hunter the run counts for
var last_time := 0.0          # [s] the last finished run (tests read it)
var _nag_i := -1              # the dash gate you were told to dash through, so it's said once
var _next_mat: Material = null
var _best_lb: Label3D = null
var _shown_arch := ""         # the Hunter whose best the start arch shows
var clock: Label = null

## The map's "trial" block ({} when this map has none).
static func data() -> Dictionary:
	return Grounds.data().get("trial", {})

## This Hunter's personal best in seconds (0 when none yet).
static func best(arch: String) -> float:
	return float((Save.d.get("time_trial", {}) as Dictionary).get(arch, 0.0))

## Save v13 -> v14: the time trial's personal bests start empty.
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("time_trial")) != TYPE_DICTIONARY:
		data["time_trial"] = {}

## Keeps secs as arch's best if it beats the old one, and saves. True for a new best.
static func record(arch: String, secs: float) -> bool:
	var old := best(arch)
	if old > 0.0 and secs >= old:
		return false
	if typeof(Save.d.get("time_trial")) != TYPE_DICTIONARY:
		Save.d["time_trial"] = {}
	Save.d["time_trial"][arch] = snappedf(secs, 0.01)
	Save.save_game()
	return true

func _init(match_node: Match) -> void:
	m = match_node

## Builds the arches, gates, pad and clock from the map's trial block (nothing when there is none).
func build(layer: CanvasLayer, grounds: Grounds) -> void:
	var t := data()
	if t.is_empty():
		return
	for gd in t["gates"]:
		var g := Gate.new()
		var p := Grounds.v3(gd["at"])
		g.at = Vector3(p.x, m.world.ground_at(p.x, p.z) + float(gd["h"]), p.z)
		g.move = String(gd.get("move", ""))
		gates.append(g)
	start = _on_ground(Grounds.v3(t["start"]))
	finish = _on_ground(Grounds.v3(t["finish"]))
	pad_at = _on_ground(Grounds.v3(t["pad"]["at"]))
	pad_land = _on_ground(Grounds.v3(t["pad"]["land"]))
	_next_mat = Models.toon(NEXT_COL, true, 0.6)
	for i in gates.size():
		_place_gate(i, grounds)
	_best_lb = _arch(start, gates[0].at, "TIME TRIAL", grounds)
	_arch(finish, finish * 2.0 - gates[-1].at, "FINISH", grounds)
	var pad := Models.jump_pad(ARCH_COL)
	pad.position = pad_at
	pad.rotation.y = atan2(-(pad_land.x - pad_at.x), -(pad_land.z - pad_at.z))
	m.add_child(pad)
	clock = Label.new()
	clock.position = Vector2(0, 104)
	clock.size = Vector2(1280, 30)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_theme_font_size_override("font_size", 26)
	clock.add_theme_color_override("font_color", NEXT_COL)
	clock.add_theme_color_override("font_outline_color", Color.BLACK)
	clock.add_theme_constant_override("outline_size", 8)
	clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock.visible = false
	layer.add_child(clock)
	_light(0)
	show_best()

func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, m.world.ground_at(p.x, p.z), p.z)

## An air ring facing from the gate before it to the one after, with the move it asks for over it.
func _place_gate(i: int, grounds: Grounds) -> void:
	var g := gates[i]
	var from := start if i == 0 else gates[i - 1].at
	var to := finish if i == gates.size() - 1 else gates[i + 1].at
	var dir := Vector2(to.x - from.x, to.z - from.z).normalized()
	g.node = Models.air_ring()
	g.node.position = g.at
	g.node.rotation.y = atan2(dir.x, dir.y)
	g.ring = g.node.get_node("Ring")
	m.add_child(g.node)
	var tag := "%d" % (i + 1)
	if MOVE_TAG.has(g.move):
		tag += "  " + String(MOVE_TAG[g.move])
	var lb := grounds.label_3d(tag, NEXT_COL, 1.6)
	lb.position = Vector3(0, 1.9, 0)
	g.node.add_child(lb)

## The lair gate without its bars, facing toward `ahead`, with a sign over it. Returns the sign.
func _arch(at: Vector3, ahead: Vector3, text: String, grounds: Grounds) -> Label3D:
	var arch := BossModels.gate(ARCH_W, ARCH_COL)
	arch.get_node("Bars").free()
	arch.position = at
	arch.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
	m.add_child(arch)
	var lb := grounds.label_3d(text, ARCH_COL, 2.4)
	lb.position = at + Vector3(0, 4.5, 0)
	m.add_child(lb)
	return lb

## Shows the current Hunter's best over the start arch.
func show_best() -> void:
	if _best_lb == null or m.player == null:
		return
	_shown_arch = m.player.arch
	var b := best(_shown_arch)
	_best_lb.text = "TIME TRIAL\nBest  %s" % (_fmt(b) if b > 0.0 else "none yet")

static func _fmt(secs: float) -> String:
	return "%d:%05.2f" % [floori(secs / 60.0), fmod(secs, 60.0)]

## Ends a run without a time (a fall, a Hunter swap).
func stop() -> void:
	running = false
	if clock:
		clock.visible = false
	_light(0)

## Per frame (from Grounds.tick): the pad, the start arch, the next gate, the finish, the clock.
func tick(dt: float) -> void:
	var P: Hunter = m.player
	if gates.is_empty() or P == null or P.downed:
		return
	_pad(P)
	if P.arch != _shown_arch:
		stop()
		show_best()
	if _under(P, start):
		running = true
		run_t = 0.0
		next_i = 0
		_nag_i = -1
		run_arch = P.arch
		_light(0)
		clock.visible = true
	if not running:
		return
	run_t += dt
	if next_i < gates.size():
		_try_gate(P)
	elif _under(P, finish):
		_finish(P)
		return
	clock.text = "%s   ·   gate %d / %d   ·   best %s" % [_fmt(run_t), mini(next_i + 1, gates.size()), gates.size(),
		_fmt(best(run_arch)) if best(run_arch) > 0.0 else "-"]

func _under(P: Hunter, arch_at: Vector3) -> bool:
	return P.flat_dist(arch_at) < ARCH_R and P.pos.y - arch_at.y < ARCH_H and P.pos.y > arch_at.y - 0.5

func _try_gate(P: Hunter) -> void:
	var g := gates[next_i]
	if (P.pos + Vector3(0, BODY_UP, 0)).distance_to(g.at) > GATE_R:
		return
	if g.move == "dash" and P.roll_t <= 0.0:
		if _nag_i != next_i and m.hud:
			m.hud.toast_small("Dash through this gate", NEXT_COL)
		_nag_i = next_i
		return
	m.sfx("ping", g.at, -6.0, 1.0 + 0.04 * next_i)
	m.fx.ring(g.at, 1.4, NEXT_COL, 0.3)
	next_i += 1
	_light(next_i)

func _finish(P: Hunter) -> void:
	running = false
	last_time = run_t
	clock.visible = false
	var old := best(run_arch)
	var beat := record(run_arch, run_t)
	m.sfx("unlock", P.pos, -4.0, 1.2 if beat else 1.0)
	_light(0)
	show_best()
	if m.hud == null:
		return
	if beat and old > 0.0:
		m.hud.toast("Time trial  %s  ·  new best (was %s)" % [_fmt(run_t), _fmt(old)], NEXT_COL)
	elif beat:
		m.hud.toast("Time trial  %s  ·  your first best" % _fmt(run_t), NEXT_COL)
	else:
		m.hud.toast("Time trial  %s  ·  best %s" % [_fmt(run_t), _fmt(old)], ARCH_COL)

## Gates before `from` are gone, gate `from` is gold, the rest wait in their own colour.
func _light(from: int) -> void:
	for i in gates.size():
		var g := gates[i]
		g.node.visible = i >= from
		g.ring.material_override = _next_mat if i == from else null

## The course's jump pad throws you onto the glide tower, as the map's own pads do.
func _pad(P: Hunter) -> void:
	if not P.pad.is_empty() or P.vel.y > 0.5 or P.flat_dist(pad_at) > PAD_R:
		return
	if P.pos.y - pad_at.y < 0.4 and P.pos.y - pad_at.y > -0.3:
		P.pad_launch(pad_land)
		m.sfx("jump", P.pos, -2.0, 0.8)
		m.fx.burst(P.pos + Vector3(0, 0.3, 0), ARCH_COL, 16, 5.0, 0.5, 2.0)
