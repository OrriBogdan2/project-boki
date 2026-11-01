class_name HomeParkour
extends RefCounted
## The parkour course on the Training Grounds: a loop of small isles east and south of the
## practice isle that teaches the movement kit in order. Jump two gaps, hop up a step, jump at a
## wall, pull up a high ledge, glide a gap through air rings, ride a jump pad, dash two gaps where
## the gusts fold your glider, ride a drifting raft, and finish on a podium above the practice isle.
##
## Walk through the Start gate to run it against the clock. Checkpoints put you back where you
## were when you fall; your best time (and the path you took, shown as a ghost on later runs) is
## kept on your profile (Save.d["parkour"]). Every piece uses the home's own movement (walk, jump,
## mantle, glide, dash with your class's charges); --parkour-check runs it for every class.

## The course's ground, carved into the home's tile grid before the main island grows round it
## (HomeLayout.make_world): [island id, x0, z0, x1, z1, terrace level]. Terraces are 0.8m each.
const COURSE := [
	["training", 46, 57, 49, 61, 0],             # a strip joining the practice isle to the Start isle
	["training_start", 50, 57, 53, 61, 0],       # Start gate
	["training_hop", 56, 58, 58, 60, 0],         # 1. jump the gaps (2 tiles, then 3 and a step up)
	["training_climb", 62, 58, 64, 60, 1],       # checkpoint
	["training_climb", 65, 58, 66, 60, 2],       # 2. a hop (+0.8m)
	["training_climb", 67, 58, 68, 60, 4],       # 3. jump at the wall (+1.6m)
	["training_climb", 69, 57, 72, 61, 7],       # 4. a high pull-up (+2.4m): the tower, checkpoint
	["training_glide", 80, 56, 86, 67, 1],       # 5. glide the 7m gap through the rings; checkpoint
	["training_ledge", 68, 64, 72, 67, 4],       # 6. the jump pad lands you here; checkpoint
	["training_dash", 59, 64, 62, 67, 4],        # 7. a 5m gap: dash and jump
	["training_dash2", 50, 64, 53, 67, 4],       # 8. a 5m gap: jump and dash in the air; checkpoint
	["training_finish", 38, 64, 43, 67, 4],      # 9. ride the raft over; the Finish gate
	["training", 37, 62, 43, 63, 0],             # the practice isle runs up to the podium's foot
]
const AREA := Rect2(29.0, 50.5, 60.0, 19.0)     # the Training Grounds and the air between its isles
const GUSTS := Rect2(44.5, 62.5, 36.0, 6.0)     # over the dash gaps and the raft: no gliding here
const START_X := 51.0                           # the Start gate's line (walk east through it)
const FINISH_X := 41.5                          # the Finish gate's line (walk west through it)
const RINGS := [Vector3(75.5, 7.0, 59.0), Vector3(78.3, 5.9, 59.0)]
const PAD := Vector3(82.5, 0.8, 65.5)           # the jump pad on the glide isle...
const PAD_TO := Vector3(70.4, 3.2, 65.5)        # ...throws you onto the ledge
const PAD_T := 1.15
const RAFT_Z := 65.5
const RAFT_Y := 3.2
const RAFT_HALF := 1.2
const RAFT_X := [45.4, 48.6]                    # the raft drifts between these (its centre)
const RAFT_PERIOD := 7.0
## [name, spawn (x, z), the rect you have to stand in to reach it]
const CHECKS := [
	["Start", Vector2(52.0, 59.5), Rect2(50, 57, 4, 5)],
	["Step", Vector2(63.0, 59.5), Rect2(62, 58, 3, 3)],
	["Tower", Vector2(70.5, 59.5), Rect2(69, 57, 4, 5)],
	["Landing", Vector2(83.0, 60.0), Rect2(80, 56, 7, 12)],
	["Ledge", Vector2(70.0, 65.8), Rect2(68, 64, 5, 4)],
	["Gusts", Vector2(51.8, 65.5), Rect2(50, 64, 4, 4)],
]
const SIGNS := [
	["Parkour: walk through the gate to start the clock", Vector3(49.6, 0.0, 56.2)],
	["Jump the gaps", Vector3(55.0, 0.0, 57.4)],
	["Hop up, jump at the wall, pull up", Vector3(64.2, 0.8, 57.4)],
	["Glide through the rings (hold Space)", Vector3(73.4, 5.6, 56.6)],
	["Jump pad", Vector3(82.5, 0.8, 64.0)],
	["Gusts fold gliders: dash the gaps (Shift)", Vector3(66.0, 3.2, 63.4)],
	["Ride the raft", Vector3(51.6, 3.2, 63.6)],
]

var t: HomeTraining
var h
var root: Node3D
var raft: Node3D = null
var raft_x := 47.0
var raft_dx := 0.0
var ring_nodes: Array = []
var ring_cd := {}              # ring index -> seconds before it boosts again
var pad_cd := 0.0
var flags: Array = []          # checkpoint flag nodes (their cloth lights up once reached)
var clock := 0.0               # the raft's clock (always running)
## the run in progress: {t: seconds, cp: index reached, path: [[x, y, z] every 0.1s], rec_t}; empty when idle
var run := {}
var last_x := 0.0
var hud: Control = null
var hud_time: Label = null
var hud_sub: Label = null
var ghost: Node3D = null
var ghost_path: Array = []
var bot = null                 # a ParkourBot driving the controls (tests and demos)
var stats := {"leaves": 0, "climbs": 0, "climbs_done": 0, "falls": 0, "rings": 0, "pads": 0, "finished": 0}
var finished_t := -1.0

func _init(training) -> void:
	t = training
	h = training.h

# ------------------------------------------------------------------ the ground
## Carves the course into the world (before the main island grows, so it keeps clear of it).
static func carve(world: World) -> void:
	var ids := {}
	for k in world.islands.size():
		ids[String(world.islands[k]["id"])] = k
	for r in COURSE:
		var id := String(r[0])
		if not ids.has(id):
			world.islands.append({"id": id, "c": Vector2((r[1] + r[3] + 1) * 0.5, (r[2] + r[4] + 1) * 0.5),
				"r": float(maxi(r[3] - r[1], r[4] - r[2]) + 1) * 0.5, "base": 0, "cells": []})
			ids[id] = world.islands.size() - 1
		var ii: int = ids[id]
		for z in range(int(r[2]), int(r[4]) + 1):
			for x in range(int(r[1]), int(r[3]) + 1):
				if not world.inb(x, z): continue
				var i := world.idx(x, z)
				var old := world.island[i]
				if old >= 0 and old != ii:
					(world.islands[old]["cells"] as Array).erase(Vector2i(x, z))
				world.kind[i] = World.T_GROUND
				world.level[i] = int(r[5])
				world.island[i] = ii
				world.depth[i] = -(2.4 + float(r[5]) * 0.15)
				if old != ii:
					(world.islands[ii]["cells"] as Array).append(Vector2i(x, z))

## Tile rects the build mode keeps off (the whole course).
static func reserved() -> Array:
	var out: Array = []
	for r in COURSE:
		out.append([int(r[1]) - 1, int(r[2]) - 1, int(r[3]) + 1, int(r[4]) + 1])
	return out

static func on_course(world: World, p: Vector3) -> bool:
	return String(world.island_id(p.x, p.z)).begins_with("training_")

## After the rim trees go in: none on the course, and the gates and signs keep their tiles.
func prepare() -> void:
	var w: World = h.world
	for r in COURSE:
		for z in range(int(r[2]), int(r[4]) + 1):
			for x in range(int(r[1]), int(r[3]) + 1):
				if w.inb(x, z):
					var i := w.idx(x, z)
					if w.kind[i] == World.T_BLOCK: w.kind[i] = World.T_GROUND
					w.no_deco[i] = true
	# a stone path from the practice isle to the Start gate
	for x in range(44, 54):
		for z in [59]:
			w.paint_tile(x, z, Color("b9a98a"))

# ------------------------------------------------------------------ the models
func build() -> void:
	root = Node3D.new(); root.name = "Parkour"; h.add_child(root)
	_gate(Vector3(START_X, 0.0, 59.5), "START", Color("8fe0a0"))
	_gate(Vector3(FINISH_X, 3.2, 65.5), "FINISH", Color("f2c84a"))
	for s in SIGNS:
		var l := t._label(root, String(s[0]), (s[1] as Vector3) + Vector3(0, 2.2, 0), UI.INK, 30)
		l.name = "Sign"
	for i in CHECKS.size():
		if i == 0: continue
		var sp: Vector2 = CHECKS[i][1]
		var y: float = h.world.ground_at(sp.x, sp.y)
		var f := Models.banner(Color("5a6478"))
		f.position = Vector3(sp.x - 0.9, y, sp.y - 1.1); f.scale = Vector3.ONE * 0.55
		root.add_child(f)
		flags.append(f)
	for i in RINGS.size():
		var rn := Models.air_ring()
		rn.position = RINGS[i]
		rn.rotation.y = PI * 0.5     # facing along the course (east)
		root.add_child(rn)
		ring_nodes.append(rn)
	var pad := Node3D.new(); pad.position = PAD; root.add_child(pad)
	Models.part(pad, Models.cyl(0.8, 0.85, 0.14, 22), Models.toon(Color("4a5368")), Vector3(0, 0.07, 0))
	Models.part(pad, Models.cyl(0.6, 0.6, 0.03, 22), Models.glow_mat(Color(1.0, 0.8, 0.35, 0.8)), Vector3(0, 0.15, 0))
	for k in 3:
		Models.part(pad, Models.box(0.16, 0.04, 0.5), Models.glow_mat(Color(1.0, 0.95, 0.7, 0.9)), Vector3(-0.25 + k * 0.0, 0.18, 0), Vector3.ONE, Vector3(0, PI * 0.5, 0)).position.x = -0.35 + k * 0.3
	# the gusts: streaks of wind drifting across the dash gaps
	var gust := CPUParticles3D.new()
	gust.amount = 70; gust.lifetime = 1.6; gust.local_coords = false
	gust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	gust.emission_box_extents = Vector3(GUSTS.size.x * 0.5, 2.5, GUSTS.size.y * 0.5)
	gust.position = Vector3(GUSTS.position.x + GUSTS.size.x * 0.5, 4.5, GUSTS.position.y + GUSTS.size.y * 0.5)
	gust.direction = Vector3(0, -0.3, 1); gust.spread = 8.0
	gust.initial_velocity_min = 5.0; gust.initial_velocity_max = 8.0; gust.gravity = Vector3.ZERO
	var gm := QuadMesh.new(); gm.size = Vector2(0.06, 1.2)
	gust.mesh = gm
	gust.material_override = Models.glow_mat(Color(0.85, 0.95, 1.0, 0.35))
	gust.particle_flag_align_y = true
	root.add_child(gust)
	_build_raft()
	_update_flags()

func _gate(at: Vector3, txt: String, col: Color) -> void:
	var g := Node3D.new(); g.position = at; root.add_child(g)
	var stone := Models.toon(Color("8a8f9c")); var dark := Models.toon(Color("5a5f6c"))
	for sz in [-1.0, 1.0]:
		Models.part(g, Models.box(0.36, 2.8, 0.36), stone, Vector3(0, 1.4, 2.2 * sz))
		Models.part(g, Models.box(0.5, 0.2, 0.5), dark, Vector3(0, 0.1, 2.2 * sz))
		Models.part(g, Models.sphere(0.16, 10), Models.toon(col, false, 1.2), Vector3(0, 2.95, 2.2 * sz))
	Models.part(g, Models.box(0.3, 0.32, 4.8), dark, Vector3(0, 2.75, 0))
	Models.part(g, Models.box(0.05, 0.55, 2.4), Models.toon(col), Vector3(-0.17, 2.3, 0))
	Models.part(g, Models.box(0.04, 0.05, 4.0), Models.glow_mat(Color(col, 0.6)), Vector3(0, 0.03, 0))
	var l := t._label(g, txt, Vector3(0, 3.45, 0), col, 46)
	l.name = "GateLabel"

func _build_raft() -> void:
	raft = Node3D.new(); raft.name = "Raft"; root.add_child(raft)
	var wood := Models.toon(Color("8a6242")); var dark := Models.toon(Color("5e4030"))
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for k in 5:
		Models.part(raft, Models.box(RAFT_HALF * 2.0, 0.16, 0.44), wood if k % 2 == 0 else Models.toon(Color("9a7050")), Vector3(0, -0.08, -0.96 + k * 0.48), Vector3.ONE, Vector3(0, rng.randf_range(-0.03, 0.03), 0))
	for sx in [-1.0, 1.0]:
		Models.part(raft, Models.box(0.14, 0.14, RAFT_HALF * 2.0), dark, Vector3(sx * (RAFT_HALF - 0.1), -0.2, 0))
	# a balloon of glowing moss holds it up
	Models.part(raft, Models.sphere(0.4, 12), Models.toon(Color("8fe0c0"), true, 0.5), Vector3(0, -0.75, 0), Vector3(1.4, 0.8, 1.4))
	raft.position = Vector3(raft_x, RAFT_Y, RAFT_Z)

func _update_flags() -> void:
	var cp := int(run.get("cp", -1))
	for i in flags.size():
		var f: Node3D = flags[i]
		var mi := f.get_node_or_null("Flag") as MeshInstance3D
		if mi:
			mi.material_override = Models.toon(Color("8fe0a0") if cp >= i + 1 else Color("5a6478"), true, 0.3 if cp >= i + 1 else 0.0)

# ------------------------------------------------------------------ hooks the home's movement asks
## The raft's deck height at (x, z), or World.VOID.
func plat_top(x: float, z: float) -> float:
	if raft and absf(x - raft_x) <= RAFT_HALF and absf(z - RAFT_Z) <= RAFT_HALF:
		return RAFT_Y
	return World.VOID

func no_glide(p: Vector3) -> bool:
	return GUSTS.has_point(Vector2(p.x, p.z))

## Where a fall puts you back: the last checkpoint of the run (INF when not running).
func respawn_at() -> Vector3:
	if run.is_empty():
		return Vector3.INF
	stats["falls"] += 1
	var sp: Vector2 = CHECKS[int(run["cp"])][1]
	return Vector3(sp.x, 0, sp.y)

func running() -> bool:
	return not run.is_empty()

# ------------------------------------------------------------------ every frame
## Before the player moves: the bot (tests and demos) sets the controls.
func pre_tick(d: float) -> void:
	if bot:
		bot.drive(d)

func tick(d: float) -> void:
	clock += d
	pad_cd = maxf(0.0, pad_cd - d)
	for k in ring_cd.keys():
		ring_cd[k] = maxf(0.0, float(ring_cd[k]) - d)
	# the raft drifts back and forth, carrying whoever stands on it
	var ox := raft_x
	raft_x = lerpf(RAFT_X[0], RAFT_X[1], 0.5 - 0.5 * cos(clock * TAU / RAFT_PERIOD))
	raft_dx = raft_x - ox
	if raft: raft.position = Vector3(raft_x, RAFT_Y + sin(clock * 1.7) * 0.0, RAFT_Z)
	var p: Vector3 = h.ppos
	var standing: bool = h.climb.is_empty() and h.pvy == 0.0 and not h.gliding and absf(h.py - h._ground_h(p.x, p.z)) < 0.03
	if standing and absf(h.py - RAFT_Y) < 0.03 and plat_top(p.x - raft_dx, p.z) > World.VOID + 1.0 and h.world.is_void(p.x, p.z):
		h.ppos.x += raft_dx
		h.player.position = h.ppos + Vector3(0, h.py, 0)
		p = h.ppos
	# air rings: fly through for a burst of speed along the course, the glider pops open
	var body: Vector3 = p + Vector3(0, h.py + 0.8, 0)
	for i in RINGS.size():
		if float(ring_cd.get(i, 0.0)) > 0.0: continue
		if body.distance_to(RINGS[i]) < 1.6 and h.py > h._ground_h(p.x, p.z) + 0.3:
			ring_cd[i] = 2.0
			stats["rings"] += 1
			var hv := Vector2(h.pvel.x, h.pvel.z)
			var spd := minf(maxf(hv.length(), Hunter.GLIDE_SPEED) + 4.0, Hunter.GLIDE_MAX)
			h.pvel = Vector3(spd, 0, 0)
			h.pvy = maxf(h.pvy, 2.0)
			h.gliding = true
			h.fx.ring(RINGS[i], 1.4, Color(0.55, 0.9, 1.0, 0.9), 0.35)
			Sfx.play("whoosh", null, -6.0, 0.1, 1.4)
	# the jump pad: stand on it and it throws you onto the ledge
	if standing and pad_cd <= 0.0 and Vector2(p.x - PAD.x, p.z - PAD.z).length() < 0.75:
		_launch()
	# the gate lines and the checkpoints
	if standing and on_course(h.world, p) or (standing and String(h.world.island_id(p.x, p.z)) == "training"):
		if last_x < START_X and p.x >= START_X and absf(p.z - 59.5) < 2.6:
			_start_run()
		if not run.is_empty():
			# checkpoints count in order only: no skipping a section
			var i := int(run["cp"]) + 1
			if i < CHECKS.size():
				var rc: Rect2 = CHECKS[i][2]
				if rc.has_point(Vector2(p.x, p.z)):
					run["cp"] = i
					_update_flags()
					h._toast("Checkpoint: %s" % CHECKS[i][0])
					Sfx.play("unlock", null, -10.0, 0.0, 1.3)
					h.fx.burst(p + Vector3(0, h.py + 1.0, 0), Color("8fe0a0"), 10, 2.0, 0.4)
			if last_x > FINISH_X and p.x <= FINISH_X and absf(p.z - 65.5) < 2.6 and h.py > 2.0:
				if int(run["cp"]) == CHECKS.size() - 1:
					_finish()
				elif not run.has("missed"):
					run["missed"] = true
					h._toast("You missed a checkpoint: go back to the %s" % CHECKS[int(run["cp"]) + 1][0])
		last_x = p.x
	if not run.is_empty():
		run["t"] = float(run["t"]) + d
		run["rec_t"] = float(run["rec_t"]) + d
		if float(run["rec_t"]) >= 0.1:
			run["rec_t"] = 0.0
			(run["path"] as Array).append([snappedf(p.x, 0.01), snappedf(h.py, 0.01), snappedf(p.z, 0.01)])
		# a fall off the course: straight back to the checkpoint, the clock keeps running
		if h.climb.is_empty() and h.world.is_void(p.x, p.z) and plat_top(p.x, p.z) <= World.VOID + 1.0 and h.py < -2.5:
			h._respawn_safe()
		if not t.in_zone:
			_cancel()
	_tick_ghost()
	_update_hud()

func _launch() -> void:
	pad_cd = 1.0
	stats["pads"] += 1
	var y0: float = h.py
	var dy := PAD_TO.y - y0
	var v0: float = (dy + 0.5 * float(h.GRAV) * PAD_T * PAD_T) / PAD_T
	var dxz := Vector2(PAD_TO.x - h.ppos.x, PAD_TO.z - h.ppos.z)
	h.pvy = v0
	h.dash_v = dxz / PAD_T
	h.dash_t = PAD_T
	h.gliding = false
	h.climb = {}
	Sfx.play("jump", null, -4.0, 0.0, 0.8)
	h.fx.ring(PAD, 1.2, Color(1.0, 0.85, 0.4, 0.9), 0.4)

func _start_run() -> void:
	run = {"t": 0.0, "cp": 0, "path": [], "rec_t": 0.0}
	finished_t = -1.0
	_update_flags()
	_build_hud()
	ghost_path = (_pk().get("ghost", []) as Array)
	h._toast("Go! The clock is running")
	Sfx.play("unlock", null, -6.0, 0.0, 1.1)

func _cancel() -> void:
	run = {}
	_update_flags()
	if is_instance_valid(ghost): ghost.visible = false
	if is_instance_valid(hud): hud.queue_free()
	hud = null

## The profile's parkour record: {best, by_cls: {cls: best}, ghost: [[x, y, z], ...], runs}.
func _pk() -> Dictionary:
	if typeof(Save.d.get("parkour")) != TYPE_DICTIONARY:
		Save.d["parkour"] = {"best": 0.0, "by_cls": {}, "ghost": [], "runs": 0}
	return Save.d["parkour"]

func _finish() -> void:
	var tm := float(run["t"])
	var pk := _pk()
	var cls: String = Data.class_of_save() if not (t.in_zone and t.try.has("cls")) else String(t.try["cls"])
	pk["runs"] = int(pk.get("runs", 0)) + 1
	var best := float(pk.get("best", 0.0))
	var pb := best <= 0.0 or tm < best
	if pb:
		pk["best"] = snappedf(tm, 0.01)
		pk["ghost"] = run["path"]
	var bc: Dictionary = pk.get("by_cls", {})
	if float(bc.get(cls, 0.0)) <= 0.0 or tm < float(bc[cls]):
		bc[cls] = snappedf(tm, 0.01)
	pk["by_cls"] = bc
	Save.save_game()
	stats["finished"] += 1
	finished_t = tm
	h._toast(("New best! %s" if pb else "Finished in %s") % fmt(tm))
	Sfx.play("unlock", null, -2.0)
	h.fx.burst(h.ppos + Vector3(0, h.py + 1.2, 0), Color("f2c84a"), 24, 3.5, 0.6)
	run = {}
	_update_flags()
	if is_instance_valid(ghost): ghost.visible = false
	_update_hud(true)

static func fmt(s: float) -> String:
	return "%d:%05.2f" % [int(s) / 60, fmod(s, 60.0)]

# ------------------------------------------------------------------ your best run's ghost
func _tick_ghost() -> void:
	if run.is_empty() or ghost_path.size() < 2:
		if is_instance_valid(ghost): ghost.visible = false
		return
	if not is_instance_valid(ghost):
		ghost = Node3D.new(); ghost.name = "Ghost"; root.add_child(ghost)
		var gm := Models.glow_mat(Color(0.7, 0.9, 1.0, 0.35))
		Models.part(ghost, Models.capsule(0.28, 1.2), gm, Vector3(0, 0.7, 0))
		Models.part(ghost, Models.sphere(0.22, 10), gm, Vector3(0, 1.5, 0))
		t._label(ghost, "best", Vector3(0, 2.1, 0), Color(0.75, 0.92, 1.0, 0.8), 26)
	var f := float(run["t"]) / 0.1
	var i := clampi(int(f), 0, ghost_path.size() - 1)
	var j := mini(i + 1, ghost_path.size() - 1)
	var a: Array = ghost_path[i]; var b: Array = ghost_path[j]
	var u := clampf(f - i, 0.0, 1.0)
	ghost.position = Vector3(lerpf(a[0], b[0], u), lerpf(a[1], b[1], u), lerpf(a[2], b[2], u))
	ghost.visible = true

# ------------------------------------------------------------------ the clock
func _build_hud() -> void:
	if is_instance_valid(hud): hud.queue_free()
	var card := UI.card(Color(0.06, 0.07, 0.11, 0.86), 10, 12)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(2); card.add_child(v)
	v.add_child(UI.label("PARKOUR", 13, Color("9ff0e0"), UI.big))
	hud_time = UI.label("0:00.00", 34, UI.INK, UI.big)
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hud_time)
	hud_sub = UI.label("", 14, UI.MUTED)
	hud_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hud_sub)
	h.root_ui.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud = card

func _update_hud(final := false) -> void:
	if not is_instance_valid(hud) or hud_time == null:
		return
	var best := float(_pk().get("best", 0.0))
	if final or run.is_empty():
		if finished_t >= 0.0:
			hud_time.text = fmt(finished_t)
			hud_time.add_theme_color_override("font_color", UI.GOLD if best > 0.0 and absf(best - finished_t) < 0.011 else UI.INK)
			hud_sub.text = "Best %s  ·  walk through Start to go again" % fmt(best)
		return
	hud_time.text = fmt(float(run["t"]))
	var ahead := ""
	if ghost_path.size() > 1 and best > 0.0:
		ahead = "  ·  best %s" % fmt(best)
	hud_sub.text = "Checkpoint %d / %d%s" % [int(run["cp"]) + 1, CHECKS.size(), ahead]
