extends RefCounted
## --mob-anim-check: the sculpted monsters move in every state (MobAnim). For each kind: every state it can be in
## has keyed tracks that really move, name pivots the model has, and loop cleanly; the wind-up on the body is the
## same fraction as the ground telegraph and lasts exactly as long; the posed pivot follows the key; and 30
## monsters pose in under PERF_MS. Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const MIN_MOVE := 0.02        # rad / m / scale: a state whose largest track moves less than this is static
const PERF_MS := 0.5          # ms: posing 30 monsters in a frame
const PERF_FRAMES := 300
const DT := 1.0 / 60.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MOBANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

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
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for o in m.hunters:
		if o != m.player: o.ctrl = "idle"
	for k in KINDS:
		_windup(m, k)
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
	var P: Hunter = m.player
	var mb := m.spawn_mob(k, P.pos + Vector3(2.0, 0, 0))
	mb.tgt = P
	mb.cd = 0.0
	mb.engaged = true
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

## How far the first wind-up track's pivot is from where its key says it should be, as a share of that track's travel.
func _follow(mb: Mob, rig: MobAnim.Rig, phase: float) -> float:
	var tr: Array = rig.def["states"][MobAnim.WINDUP][0]
	var tg: PackedInt32Array = tr[0]
	var slot := tg[0] / MobAnim.STRIDE
	var ch := tg[0] % MobAnim.STRIDE
	var cv: PackedFloat32Array = tr[2]
	var x := phase * MobAnim.SAMPLES
	var i := mini(int(x), MobAnim.SAMPLES - 1)
	var want := (cv[i] + (cv[i + 1] - cv[i]) * (x - i)) * float((tr[1] as PackedFloat32Array)[0])
	var n := rig.nodes[slot]
	var got := 0.0
	if ch < 3: got = n.rotation[ch] - rig.rest_r[slot][ch]
	elif ch < 6: got = n.position[ch - 3] - rig.rest_p[slot][ch - 3]
	elif ch < 9: got = n.scale[ch - 6] - 1.0
	var travel := 0.0
	for v in cv:
		travel = maxf(travel, absf(v))
	return absf(got - want) / maxf(travel, 0.1)

## 30 monsters of every kind in every state, posed 300 frames: the mean cost of one frame's poses.
func _perf(m: Match) -> void:
	var P: Hunter = m.player
	m.cam.focus = P.pos
	var crowd: Array = []
	for i in 30:
		var k: String = KINDS[i % KINDS.size()]
		var mb := m.spawn_mob(k, P.pos + Vector3(2.0 + (i % 6) * 1.5, 0, (i / 6) * 1.5))
		match i % 6:
			1:
				mb.vel = Vector3(2.0, 0, 0)
			2:
				mb.vel = Vector3(5.0, 0, 0)
			3:
				mb.st = "windup"
				mb.st_t = 0.3
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
			if MobAnim.pose(mb, DT): posed += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / PERF_FRAMES
	ok(posed == crowd.size() * PERF_FRAMES, "all 30 monsters are posed every frame (%d)" % posed)
	ok(ms < PERF_MS, "30 monsters pose in %.3f ms a frame (budget %.1f)" % [ms, PERF_MS])
