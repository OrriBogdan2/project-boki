extends RefCounted
## --mob-anim-check: the sculpted monsters move in every state (MobAnim). For each kind: every state it can be in
## has keyed tracks that really move, name pivots the model has, and loop cleanly; the wind-up on the body is the
## same fraction as the ground telegraph and lasts exactly as long; the posed pivot follows the key; the feet of every
## legged kind and lair boss keep pace with the floor; and 30 monsters pose in under PERF_MS. Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const MIN_MOVE := 0.02  # rad / m / scale: a state whose largest track moves less than this is static
const PERF_MS := 0.5  # ms: posing 30 monsters in a frame
const PERF_FRAMES := 300
const BOSSES := ["colossus", "serpent", "brood"]
const PACES := [["patrol", 0.3], ["slowed", 0.55], ["chase", 1.0], ["enraged", 1.25]]  # x data speed (Mob/Boss.sim)
const SLIDE_K := 0.15  # the skate at chase pace may be this share of the stride
const SETTLE_FRAMES := 60  # frames for the pivots to catch the walk before the skate is measured
const CYCLE_FRAMES := 240
const DT := 1.0 / 60.0

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("MOBANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	_tables()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	for k in KINDS:
		_windup(m, k)
	for k in KINDS:
		_gait(m, k)
	for k in BOSSES:
		_boss_gait(m, k)
	_perf(m)
	m.queue_free()
	print("MOBANIM DONE, failures: %d" % bad)
	main.get_tree().quit(mini(bad, 1))


## Every state a kind can enter has tracks; they name real pivots, move, and loops close.
func _tables() -> void:
	for k in KINDS:
		var body := MobModels.build(k).get_node("Body")
		for s in MobAnim.STATES.size():
			if not MobAnim.state_needed(k, s):
				continue
			var trs := MobAnim.tracks(k, s)
			var span := 0.0
			var seam := 0.0
			for tr in trs:
				var cv: PackedFloat32Array = tr[2]
				var lo := cv[0]
				var hi := cv[0]
				for v in cv:
					lo = minf(lo, v)
					hi = maxf(hi, v)
				span = maxf(span, hi - lo)
				seam = maxf(seam, absf(cv[0] - cv[MobAnim.SAMPLES]))
			var what := "%s %s: %d tracks, largest span %.2f" % [k, MobAnim.STATES[s], trs.size(), span]
			ok(not trs.is_empty() and span >= MIN_MOVE, what)
			if MobAnim.LOOPS[s]:
				ok(seam < 0.001, "%s %s: loop closes (seam %.3f)" % [k, MobAnim.STATES[s], seam])
		var missing: Array = []
		for nm in MobAnim.table(k)["slots"]:
			if MobAnim.pivot(body, String(nm)) == null:
				missing.append(nm)
		ok(missing.is_empty(), "%s: every pivot exists in the model (missing %s)" % [k, str(missing)])


## Forces an attack and steps the real sim: the body phase must equal what the telegraph shows each frame, the
## wind-up must last the data's windup seconds, and the pivots must follow the key.
func _windup(m: Match, k: String) -> void:
	var md: Dictionary = Data.MOBS[k]
	if not MobAnim.state_needed(k, MobAnim.WINDUP):
		return
	var p: Hunter = m.player
	var mb := m.spawn_mob(k, p.pos + Vector3(2.0, 0, 0))
	mb.tgt = p
	mb.cd = 0.0
	mb.engaged = true
	mb.aggro(p, "check")
	mb._go(Mob.S.CHASE, "check")
	mb._begin_attack()
	ok(mb.tele != null and MobAnim.state_of(mb) == MobAnim.WINDUP, "%s: wind-up starts with its telegraph" % k)
	var wind := float(md["windup"])
	var worst := 0.0
	var frames := 0
	var tracked := 0.0
	var rig: MobAnim.Rig = null
	while mb.st == "windup" and frames < int(wind / DT) + 8:
		mb.sim(DT)
		if mb.st != "windup" or mb.tele == null:
			break
		frames += 1
		var shown := float((mb.tele as MeshInstance3D).material_override.get_shader_parameter("progress"))
		worst = maxf(worst, absf(shown - MobAnim.phase_of(mb, MobAnim.WINDUP, 0.0)))
		mb.render(DT, 1.0)
		rig = mb.model.get_meta("mob_rig", null)
		tracked = _follow(mb, rig, shown) if rig else 1.0
	ok(worst < 0.0001, "%s: body wind-up fraction equals the telegraph's every frame (worst gap %.5f)" % [k, worst])
	var lasted := (frames + 1) * DT
	ok(absf(lasted - wind) <= DT * 1.5, "%s: wind-up lasts the telegraph, %.3f s of %.3f s" % [k, lasted, wind])
	var off_by := "%s: pivots sit on the key at wind-up end (off %.1f%% of travel)" % [k, tracked * 100.0]
	ok(rig != null and tracked < 0.05, off_by)
	# Mob.render leans every body back as it gathers; the keyed pivots must not pull that lean back to rest
	var lean := (mb.model.get_node("Body") as Node3D).rotation.x
	ok(lean > 0.1, "%s: the wind-up lean shows on the body (%.3f rad, want > 0.1)" % [k, lean])


## The feet keep pace with the floor. A scripted chase runs each kind at the speeds Mob.sim uses (PACES x its data
## speed); over a gait cycle each foot the model has (its glb's Leg* bones) travels one stride in body space, and
## the ground covered in that cycle must match it: the gap is the skate. Standing still freezes the gait and a hit
## shows on the body without leaving the walk.
func _gait(m: Match, k: String) -> void:
	var p: Hunter = m.player
	var mb := m.spawn_mob(k, p.pos + Vector3(6.0, 0, 0))
	mb.tgt = null
	_skate_all(mb, k)
	var spd := maxf(float(mb.md["speed"]), 1.0)
	mb.vel = Vector3(spd, 0, 0)
	mb.render(DT, 1.0)
	var before := mb.anim
	mb.vel = Vector3.ZERO
	for i in 10:
		mb.render(DT, 1.0)
	ok(is_equal_approx(mb.anim, before), "%s: the gait stands still when the monster stops" % k)
	mb.vel = Vector3(spd, 0, 0)
	mb.hurt(1.0, p)
	mb.render(DT, 1.0)
	ok(
		MobAnim.state_of(mb) != MobAnim.DEATH and MobAnim.state_of(mb) <= MobAnim.RUN,
		"%s: a hit keeps the walk under the hit-react" % k
	)
	mb.dead = true
	mb.visible = false


## A lair boss, woken and walked the same way (its legs are BossAnim's).
func _boss_gait(m: Match, k: String) -> void:
	var at: Vector3 = m.player.pos + Vector3(12.0, 0, 0)
	var b := Boss.new()
	b.init_boss(m, m.next_id("b"), k, at, 1.0, {"c": at, "boss": k})
	m.add_child(b)
	b.wake("check")
	b.awake_t = 10.0
	_skate_all(b, k)
	b.queue_free()


## Every pace: the skate at the chase pace must stay under SLIDE_K of the stride; the rest is reported.
func _skate_all(mb: Mob, k: String) -> void:
	var feet := _feet(mb.model)
	if feet.is_empty():
		print("MOBANIM note %s: no feet in its model, skate not measured" % k)
		return
	var spd0 := maxf(float(mb.md["speed"]), 1.0)
	for pace in PACES:
		var spd: float = spd0 * float(pace[1])
		var r := _skate(mb, feet, spd)
		var skate_cm: float = absf(r[0] - r[1]) * 100.0
		var what := (
			"%s %s %.2f m/s: skate %.1f cm per cycle (ground %.2f m, stride %.2f m, %.2f cycles/s)"
			% [k, pace[0], spd, skate_cm, r[0], r[1], r[2]]
		)
		if pace[0] == "chase":
			ok(skate_cm <= r[1] * SLIDE_K * 100.0, what)
		else:
			print("MOBANIM note %s" % what)


## Walks mb on the spot at spd for CYCLE_FRAMES after a settle: [ground m per cycle, stride m, cycles/s]. The stride
## is twice a foot's fore-aft extent in Body space: a foot is planted half the cycle and covers its extent then.
func _skate(mb: Mob, feet: Array, spd: float) -> Array:
	mb.vel = Vector3(0, 0, -spd)
	mb.anim = 0.0
	var glb := mb.model.get_node("MobGlb") as MobGlb
	var body := mb.model.get_node("Body") as Node3D
	for i in SETTLE_FRAMES:
		mb.render(DT, 1.0)
	var a0 := mb.anim
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(feet.size())
	hi.resize(feet.size())
	lo.fill(INF)
	hi.fill(-INF)
	for i in CYCLE_FRAMES:
		mb.render(DT, 1.0)
		glb.copy_pose()
		var inv := body.global_transform.affine_inverse()
		for f in feet.size():
			var skel: Skeleton3D = feet[f][0]
			var at: Vector3 = inv * (skel.global_transform * (skel.get_bone_global_pose(feet[f][1]) * feet[f][2]))
			lo[f] = minf(lo[f], at.z)
			hi[f] = maxf(hi[f], at.z)
	var hz := (mb.anim - a0) / (CYCLE_FRAMES * DT) / TAU
	var travel := 0.0
	for f in feet.size():
		travel += (hi[f] - lo[f]) / feet.size()
	return [spd / maxf(hz, 0.001), travel * 2.0, hz]


## The model's feet from its glb: for each Leg* bone, the lowest vertex it owns, in that bone's space:
## [skeleton, bone, point].
func _feet(model: Node3D) -> Array:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return []
	var skel: Skeleton3D = sks[0]
	var mi: MeshInstance3D = skel.find_children("*", "MeshInstance3D", true, false)[0]
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bn = arr[Mesh.ARRAY_BONES]
	var wt = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = bn.size() / vs.size()
	var low := {}
	for v in vs.size():
		var best := 0
		for j in range(1, per):
			if wt[v * per + j] > wt[v * per + best]:
				best = j
		var bi: int = bn[v * per + best]
		if not low.has(bi) or vs[v].y < (low[bi] as Vector3).y:
			low[bi] = vs[v]
	var out: Array = []
	for bi in skel.get_bone_count():
		if skel.get_bone_name(bi).begins_with("Leg") and low.has(bi):
			out.append([skel, bi, skel.get_bone_global_rest(bi).affine_inverse() * (low[bi] as Vector3)])
	return out


## How far the first wind-up track's pivot is from where its key says it should be, as a share of that track's travel.
func _follow(_mb: Mob, rig: MobAnim.Rig, phase: float) -> float:
	var tr: Array = rig.def["states"][MobAnim.WINDUP][0]
	var tg: PackedInt32Array = tr[0]
	var slot := int(tg[0] / float(MobAnim.STRIDE))
	var ch := tg[0] % MobAnim.STRIDE
	var cv: PackedFloat32Array = tr[2]
	var x := phase * MobAnim.SAMPLES
	var i := mini(int(x), MobAnim.SAMPLES - 1)
	var want := (cv[i] + (cv[i + 1] - cv[i]) * (x - i)) * float((tr[1] as PackedFloat32Array)[0])
	var n := rig.nodes[slot]
	var got := 0.0
	if ch < 3:
		got = n.rotation[ch] - rig.rest_r[slot][ch]
	elif ch < 6:
		got = n.position[ch - 3] - rig.rest_p[slot][ch - 3]
	elif ch < 9:
		got = n.scale[ch - 6] - 1.0
	var travel := 0.0
	for v in cv:
		travel = maxf(travel, absf(v))
	return absf(got - want) / maxf(travel, 0.1)


## 30 monsters of every kind in every state, posed 300 frames: the mean cost of one frame's poses.
func _perf(m: Match) -> void:
	var p: Hunter = m.player
	m.cam.focus = p.pos
	var crowd: Array = []
	for i in 30:
		var k: String = KINDS[i % KINDS.size()]
		var mb := m.spawn_mob(k, p.pos + Vector3(2.0 + (i % 6) * 1.5, 0, (int(i / 6.0)) * 1.5))
		match i % 6:
			1:
				mb.vel = Vector3(2.0, 0, 0)
			2:
				mb.vel = Vector3(5.0, 0, 0)
			3:
				mb.aggro(m.player, "check")
				mb._go(Mob.S.CHASE, "check")
				mb._go(Mob.S.WINDUP, "check", 0.3)
			4:
				mb.stagger_t = 1.0
			5:
				mb.flash_t = 0.06
		crowd.append(mb)
	var posed := 0
	var t0 := Time.get_ticks_usec()
	for f in PERF_FRAMES:
		for mb in crowd:
			mb.anim += DT * 4.0
			if MobAnim.pose(mb, DT):
				posed += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / PERF_FRAMES
	ok(posed == crowd.size() * PERF_FRAMES, "all 30 monsters are posed every frame (%d)" % posed)
	ok(ms < PERF_MS, "30 monsters pose in %.3f ms a frame (budget %.1f)" % [ms, PERF_MS])
