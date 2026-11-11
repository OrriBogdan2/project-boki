extends RefCounted
## --loot-open-check: the open channel's pose (WardenOpen, docs/art/wardens/CLIPS.md "Opening a box") on every Hero
## with clips. Per Hero, a chest straight ahead and a deathbox off to the side, each at an interact distance: the pose
## is on every frame of the whole channel (chest hold_s, deathbox loot_time), both wrists end within REACH of the lid,
## it goes back to the clips within RETURN_S of letting go, and a move, a dash, a cast or a hit takes it off the very
## frame it comes (and the hold reaches in again after). Then a real match (the wiring): Kael opens a chest after a
## kit move, and walks off a second one mid-hold. Never touches the save.
## --shots-dir=<dir> (GPU): instead, <dir>/loot_open_strip.png: Kael, Neve and Vex each at a chest, standing, reaching
## and holding, one row per phase.

const DT := 1.0 / 30.0
const REACH := 0.2             # m: a wrist's farthest from the lid's box once the reach is in
const CHEST_AT := Vector3(0, 0, -1.25)       # m: a chest ahead (interact range < 1.6)
const BOX_AT := Vector3(0.95, 0, -0.95)      # m: a deathbox ahead-right, 1.34 m off (range 1.5)
const STRIP := ["juggernaut", "rimewright", "gunslinger"]
const PHASES := [0.0, 0.12, 0.7]            # s into the hold: standing, reaching, holding
const SHOT := Vector2i(1080, 420)
const LIVE_MOVE := "jug_slash_r"             # Kael's kit move before he opens a chest: its id stays on his kit
const LIVE_NEXT := Vector3(0, 0, 6.0)        # m: the second chest's spot, clear of the first one's spill
const LIVE_SETTLE := 1.5       # s: that move's clip is over
const CANCELS := {"move": {"vel": Vector3(0, 0, -3.0)}, "dash": {"rolling": true}, "cast": {"cast": 0.0},
	"hit": {"hit_t": 0.0, "hit_dir": Vector2(0, 1)}}

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("OPEN FAIL ", what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			await _strip(main, a.substr(12))
			return
	var n := 0
	for id in Arch.ids():
		n += 1 if _hero(String(id)) else 0
	ok(n == 12, "12 Heroes play clips and wear the open layer (%d)" % n)
	_live(main)
	print("LOOT_OPEN_CHECK_DONE heroes %d, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## False for a Hero with no clips (Gil until his .glb has them): the rig's own hold pose plays (HunterAnim._act_legs).
func _hero(id: String) -> bool:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	var op: WardenOpen = sync.get("opener") if sync else null
	if op == null:
		ok(sync == null or sync.get("clips") == null, "%s: plays clips, so wears the open layer" % id)
		m.free()
		return false
	sync.set_process(false)
	var sk := op.skel
	var head := (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin).y
	var line := "OPEN %-11s head %.2f m" % [id, head]
	for k in ["chest", "loot"]:
		var box := Models.chest() if k == "chest" else Models.deathbox(Color.GOLD)
		box.position = CHEST_AT if k == "chest" else BOX_AT
		box.rotation.y = 0.6
		holder.add_child(box)
		line += "  " + _channel(id, m, sync, op, box, k)
		box.free()
	print(line)
	m.free()
	return true

## One channel on one box: returns the plan and the worst wrist miss, for the line.
func _channel(id: String, m: Node3D, sync: Node, op: WardenOpen, box: Node3D, kind: String) -> String:
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "act": "", "act_at": Vector3.INF}
	m.set_meta(WardenClips.STATE, s)
	for i in 10:
		sync.call("_process", DT)
	var lid := _lid_box(box)
	var dur := float(ChestLoot.R()["hold_s"]) if kind == "chest" else float(Life.R["loot_time"])
	s["act"] = kind
	s["act_at"] = WardenOpen.lid_top(box)
	var off := 0
	var worst := 0.0
	var t := 0.0
	while t < dur:
		sync.call("_process", DT)
		t += DT
		off += 1 if op.w <= 0.0 else 0
		if t > WardenOpen.REACH_S + DT:
			worst = maxf(worst, maxf(_miss(op, "hand.L", lid), _miss(op, "hand.R", lid)))
	ok(off == 0, "%s %s: the pose is on the whole %.1f s channel (%d frames off)" % [id, kind, dur, off])
	ok(worst <= REACH, "%s %s: both wrists on the lid (worst %.3f m off it, limit %.2f)" % [id, kind, worst, REACH])
	var plan := op.plan.duplicate()
	# every cancel: off the frame it comes, back in once it goes
	for c in CANCELS:
		for k in CANCELS[c]:
			s[k] = CANCELS[c][k]
		sync.call("_process", DT)
		ok(op.w == 0.0, "%s %s: a %s takes the pose off the frame it comes (w %.2f)" % [id, kind, c, op.w])
		s.merge({"vel": Vector3.ZERO, "rolling": false, "cast": 99.0, "hit_t": 99.0}, true)
		for i in int(WardenOpen.REACH_S / DT) + 2:
			sync.call("_process", DT)
		ok(op.w >= 1.0, "%s %s: the hold reaches in again after a %s" % [id, kind, c])
	s["act"] = ""
	s["act_at"] = Vector3.INF
	for i in int(WardenOpen.RETURN_S / DT) + 1:
		sync.call("_process", DT)
	ok(op.w == 0.0, "%s %s: straight back to the clips once the hold ends" % [id, kind])
	return "%s miss %.2f (step %.2f drop %.2f lean %.2f)" % [kind, worst, float(plan.get("step", -1.0)),
			float(plan.get("drop", -1.0)), float(plan.get("lean", -1.0))]

## A real match: Hunter._anim_state finds the lid, Match's chest hold is the channel.
func _live(main: Node) -> void:
	var a: RefCounted = load("res://tools/archetype_check.gd").new()
	a.main = main
	var r: Array = a.setup("juggernaut", 11.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var home: Vector3 = r[4]
	var sync := p.model.get_node_or_null("Warden/Sync")
	var op: WardenOpen = sync.get("opener") if sync else null
	ok(op != null, "live: Kael wears the open layer in a match")
	if op == null:
		return
	sync.set_process(false)
	p.ak.play(LIVE_MOVE)
	for i in int(LIVE_SETTLE / DT):
		_frame(m, p, sync)
	var on_kit := String(p.model.get_meta(WardenClips.STATE, {}).get("kmove", ""))
	ok(on_kit == LIVE_MOVE, "live: the kit move's id is still on (%s)" % on_kit)
	var c := m.add_chest(home + CHEST_AT)
	c["free"] = true
	var lid := _lid_box(c["node"])
	var on := 0
	var off := 0
	var worst := 0.0
	p.inp["interact"] = true
	while not c["open"] and on + off < 600:
		_frame(m, p, sync)
		if p.holding() != "chest":
			continue
		on += 1 if op.w > 0.0 else 0
		off += 1 if op.w <= 0.0 else 0
		if op.t > WardenOpen.REACH_S + DT:
			worst = maxf(worst, maxf(_miss(op, "hand.L", lid), _miss(op, "hand.R", lid)))
	var want := int(float(ChestLoot.R()["hold_s"]) / DT) - 1
	ok(c["open"] and off == 0 and on >= want, "live: the pose is on the whole chest hold (%d on, %d off, want %d)"
			% [on, off, want])
	ok(worst <= REACH, "live: both wrists on the chest's lid (worst %.3f m off it, limit %.2f)" % [worst, REACH])
	p.inp["interact"] = false
	for i in 12:
		_frame(m, p, sync)
	ok(op.w == 0.0, "live: back to the clips once the chest is open (w %.2f)" % op.w)
	p.teleport(home + LIVE_NEXT)
	c = m.add_chest(home + LIVE_NEXT + CHEST_AT)
	c["free"] = true
	p.inp["interact"] = true
	for i in 12:
		_frame(m, p, sync)
	ok(op.w >= 1.0, "live: reaching into the second chest (w %.2f)" % op.w)
	p.inp["move"] = Vector2(1, 0)
	var left := 0
	while Vector2(p.vel.x, p.vel.z).length() < WardenOpen.STILL and left < 30:
		_frame(m, p, sync)
		left += 1
	ok(left < 30 and op.w == 0.0, "live: walking off takes the pose off that frame (w %.2f, frame %d)" % [op.w, left])
	p.inp["move"] = Vector2.ZERO
	p.inp["interact"] = false
	m.queue_free()

func _frame(m: Match, p: Hunter, sync: Node) -> void:
	m.step(DT)
	p.render(DT, 1.0)
	sync.call("_process", DT)

func _miss(op: WardenOpen, bone: String, lid: AABB) -> float:
	var sk := op.skel
	var p := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, bone)).origin
	return p.distance_to(p.clamp(lid.position, lid.end))

func _lid_box(box: Node3D) -> AABB:
	var lid := box.find_child("Lid", true, false) as Node3D
	var out := AABB(box.global_position, Vector3.ZERO)
	var first := true
	for mi in lid.find_children("*", "MeshInstance3D", true, false):
		var g := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		out = g if first else out.merge(g)
		first = false
	return out

func _strip(main: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	# the boot cover (logo) and any screen are 2D over the world: off, or the strip shoots the splash
	for c in main.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is CanvasItem:
			(c as CanvasItem).visible = false
	main.get_window().size = SHOT
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 30)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4a5a3a"), false)
	holder.add_child(ground)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.fov = 30.0
	cam.position = Vector3(5.2, 2.6, 7.4)
	cam.look_at(Vector3(0, 0.7, -0.6))
	cam.make_current()
	var rigs: Array = []
	for i in STRIP.size():
		var id: String = STRIP[i]
		var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		m.set_meta("anim_seed", 1)
		m.position = Vector3((i - 1) * 2.6, 0, 0)
		holder.add_child(m)
		var ring := m.get_node_or_null("TeamRing") as Node3D
		if ring:
			ring.visible = false
		var box := Models.chest()
		box.position = m.position + CHEST_AT
		box.rotation.y = 0.3
		holder.add_child(box)
		var sync := m.get_node("Warden/Sync")
		sync.set_process(false)
		var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "act": "", "act_at": Vector3.INF}
		m.set_meta(WardenClips.STATE, s)
		rigs.append([sync, s, box])
	var strip := Image.create(SHOT.x, SHOT.y * PHASES.size(), false, Image.FORMAT_RGBA8)
	var t := -0.5
	for p in PHASES.size():
		while t < float(PHASES[p]):
			for r in rigs:
				if t >= 0.0:
					r[1]["act"] = "chest"
					r[1]["act_at"] = WardenOpen.lid_top(r[2])
				(r[0] as Node).call("_process", DT)
			t += DT
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(img, Rect2i(Vector2i.ZERO, SHOT), Vector2i(0, SHOT.y * p))
	strip.save_png(out.path_join("loot_open_strip.png"))
	print("LOOT_OPEN_STRIP ", out.path_join("loot_open_strip.png"))
	main.get_tree().quit(0)
