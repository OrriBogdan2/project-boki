extends RefCounted
## --clip-live-check: Kael's clips through the real match code: a Match, its Hunters, the kit's own keys and the render path
## (Hunter.render, HunterAnim, Sync). Re-equipping leaves one weapon drawn; the Warchain's throw and haul play their clips and the
## haul's lean goes where he is heading, not along the chain; a knock-out plays the death clip on screen, then he is gone.
## Never touches the save.

const DT := 1.0 / 60.0
const LEAN_OFF := 0.5          # rad: how far the haul's lean may sit off his heading

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Array) -> void:
	m.step(DT)
	for x in h:
		(x as Hunter).render(DT, 1.0)
		if x.model and x.model.has_node("Warden/Sync"):
			var sync: Node = x.model.get_node("Warden/Sync")
			sync.set_process(false)
			if x.visible or x.out:
				sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

func _shown(h: Hunter) -> int:
	var n := 0
	var gun := h.model.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			n += 1
	return n

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("juggernaut", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	for f in 10:
		_frame(m, [P])
	ok(_clips(P) != null, "Kael wears his clips in a match")
	ok(_shown(P) == 0, "one weapon drawn (%d procedural pieces)" % _shown(P))
	P.equip(P.wid)
	for f in 4:
		_frame(m, [P])
	ok(_shown(P) == 0, "one weapon after an equip (%d procedural pieces)" % _shown(P))
	# the Warchain, thrown at a foe off to the side, then hauled while he looks and steers past it
	var K: JuggernautKit = P.ak
	T.teleport(home + Vector3(10.0, 0, 0))
	A.aim_at(P, T.pos)
	K.warchain.press()
	var seen := {}
	var lean_worst := 0.0
	var off_chain := 0.0
	var reel_frames := 0
	for f in 240:
		if K.warchain.hooked() and K.warchain.state == "hooked" and f > 40:
			A.aim_at(P, P.pos + Vector3(4.0, 0, 5.0))
			P.inp["move"] = Vector2(0.6, 0.8)
			K.warchain.press()
		_frame(m, [P])
		var c := _clips(P)
		seen[c.cur] = true
		if c.cur == "reel" and c.act_w >= 1.0 and K.warchain.pulling() and Vector2(P.vel.x, P.vel.z).length() > 4.0:
			var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
			var bi := sk.find_bone("hips")
			var turn := sk.get_bone_global_pose(bi).basis * sk.get_bone_global_rest(bi).basis.inverse()
			var up := (sk.global_transform.basis * (turn * Vector3.UP)).normalized()
			var lean := Vector2(up.x, up.z).normalized()
			var head := Vector2(P.vel.x, P.vel.z).normalized()
			var line := Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).normalized()
			lean_worst = maxf(lean_worst, absf(lean.angle_to(head)))
			off_chain = maxf(off_chain, absf(head.angle_to(line)))
			reel_frames += 1
	print("LIVE clips seen: ", seen.keys())
	ok(seen.has("chain"), "the throw plays the chain clip")
	ok(seen.has("reel"), "the haul plays the reel clip")
	ok(reel_frames > 0 and lean_worst <= LEAN_OFF, "the haul leans on his heading (worst %.2f rad off it, %d frames; heading up to %.2f rad off the chain)"
			% [lean_worst, reel_frames, off_chain])
	# a knock-out
	K.warchain.state = "ready"
	P.lives = 1
	for f in 30:
		_frame(m, [P])
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, [P])
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out stays on screen and plays the death clip (clip %s, visible %s)"
			% [dead_seen, was_visible])
	for f in 60:
		_frame(m, [P])
	ok(not P.visible, "after the clip he is gone")
	print("CLIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
