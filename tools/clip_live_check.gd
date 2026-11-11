extends RefCounted
## --clip-live-check: Kael's clips through the real match code: a Match, its Hunters, the kit's own keys and the render
## path (Hunter.render, HunterAnim, Sync). Re-equipping leaves one weapon drawn; the Warchain's throw and haul play
## clips and the haul's lean goes where he is heading, not along the chain; a knock-out plays the death clip on screen,
## then he is gone. Every Hunter, each key pressed on the way up a jump and in a fall: a move seen in the air plays over
## airborne legs ("air_legs", or clips on the upper body only) unless its legs are the move (LEGS_MOVES), and one
## that lands before its end keeps the legs it had.
## Never touches the save.

const DT := 1.0 / 60.0
const LEAN_OFF := 0.5          # rad: how far the haul's lean may sit off his heading
const AIR_KEYS := ["fire", "sec", "sig", "ult"]
const AIR_HOLDS := [6, 40]      # frames a key is held: a tap and a hold
const NO_LEGS := ["ostra"]      # rides his box: no legs to plant, his clips key from the box up
## Moves whose clip is the legs' own air pose (a leap, a dive, a jump, the Quakefall's tuck) and the merge's fusion (a
## whole-body show): full-body in the air.
const LEGS_MOVES := ["jug_meteor", "lw_jump", "breah_dive", "breah_crouch", "dr_jump", "dr_dive", "mf_xform"]

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
	if WardenClips.data("kael").is_empty():
		# (a branch without Kael's art: no clip data means he plays on the procedural rig, and that has to hold too)
		ok(_clips(P) == null, "no clip data for Kael: he plays procedurally")
		print("CLIP_LIVE_DONE, failures: ", bad)
		main.get_tree().quit(1 if bad > 0 else 0)
		return
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
		if K.warchain.hooked() and f > 40:
			A.aim_at(P, P.pos + Vector3(4.0, 0, 5.0))
			P.inp["move"] = Vector2(0.6, 0.8)
			K.warchain.press()
		_frame(m, [P])
		var c := _clips(P)
		seen[c.cur] = true
		var fast := Vector2(P.vel.x, P.vel.z).length() > 4.0
		if c.cur == "reel" and c.act_w >= 1.0 and K.warchain.pulling() and fast:
			var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
			var bi := sk.find_bone("hips")
			var turn := sk.get_bone_global_pose(bi).basis * sk.get_bone_global_rest(bi).basis.inverse()
			# (in the model's own frame: the match camera leans every model toward itself)
			var up := (turn * Vector3.UP).normalized()
			var head := atan2(-P.vel.x, -P.vel.z)
			var line := atan2(-(T.pos.x - P.pos.x), -(T.pos.z - P.pos.z))
			lean_worst = maxf(lean_worst, absf(wrapf(atan2(-up.x, -up.z) + P.face - head, -PI, PI)))
			off_chain = maxf(off_chain, absf(wrapf(head - line, -PI, PI)))
			reel_frames += 1
	print("LIVE clips seen: ", seen.keys())
	ok(seen.has("chain"), "the throw plays the chain clip")
	ok(seen.has("reel"), "the haul plays the reel clip")
	ok(reel_frames > 0 and lean_worst <= LEAN_OFF, "the haul leans on his heading (worst %.2f rad, %d frames)"
			% [lean_worst, reel_frames])
	print("LIVE heading up to %.2f rad off the chain" % off_chain)
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
	m.queue_free()
	await _air_casts(main)
	print("CLIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Each Hunter's keys pressed in the air: which moves stand planted there (full body over the fall), and whether one
## that lands mid-move snaps into its stance.
func _air_casts(main: Node) -> void:
	var L = load("res://tools/air_limits_check.gd").new()
	for arch in Arch.ORDER.filter(func(a): return not a in NO_LEGS):
		var m: Match = L._match(main, arch)
		var h: Hunter = m.player
		var home := h.pos
		var planted := {}
		var snaps := {}
		for mode in ["jump", "fall"]:
			for key in AIR_KEYS:
				for hold in AIR_HOLDS:
					L._clear(h)
					h.teleport(home)
					h.vel = Vector3.ZERO
					for i in 60:
						_frame(m, [h])
					L._ready_all(h)
					if mode == "jump":
						h.inp["jump"] = true
						for i in 8:
							_frame(m, [h])
						h.inp["jump"] = false
					else:
						h.teleport(home + Vector3(0, 8, 0))
						h.grounded = false
						for i in 4:
							_frame(m, [h])
					h.inp["aim"] = h.pos + Vector3(8, -0.5, 0)
					_air_press(m, h, key, hold, planted, snaps)
		ok(planted.is_empty(), "%s: no move stands planted in the air (%s)" % [arch, str(planted.keys())])
		ok(snaps.is_empty(), "%s: a cast that lands keeps its legs (%s)" % [arch, str(snaps.keys())])
		m.queue_free()
		await main.get_tree().process_frame

func _air_press(m: Match, h: Hunter, key: String, hold: int, planted: Dictionary, snaps: Dictionary) -> void:
	var air_km := ""             # the air_legs move cast in the air, while that play of it runs
	var last_t := 0.0
	for i in 90:
		h.inp[key] = i < hold
		if key == "sec":
			h.inp["sec_hold"] = i < hold
		_frame(m, [h])
		var s: Dictionary = h.model.get_meta(WardenClips.STATE, {})
		var km := String(s.get("kmove", ""))
		var c := _clips(h)
		var tt := float(s.get("kmove_t", 0.0))
		if c == null or km != air_km or tt < last_t:
			air_km = ""
		last_t = tt
		if c == null or km == "":
			continue
		var full := c.act_w >= 0.99 and c.up_w <= 0.0
		if not bool(s.get("grounded", true)):
			if full and not km in LEGS_MOVES:
				planted[km] = true
			if bool((c.d["kmoves"].get(km, {}) as Dictionary).get("air_legs", false)):
				air_km = km
		elif air_km == km and c.act_w > 0.5:
			snaps[km] = true
