extends RefCounted
## --first-cast-check: what an ability costs the first time it goes off in a process (its scenes,
## particles, decals, meshes and sounds made or loaded mid-fight), shader compiles aside (those are
## Match.warm_up's). For each of the 12 Hunters: a fresh Training Area match with that Hunter, loaded
## the way Main loads one (start, then warm_up), a target in front, then LMB, RMB, E, R, Shift and Q
## (an active glove, a different one per Hunter) once each, then each twice more. A bridge glove gets a
## "span" row too, cast over a strip of abyss cut in front (the yard has none, so its Q row lays nothing).
## A slot's spike is the worst frame in the window after its first press; its first-use cost is that minus
## the cheaper repeat window. FAIL: a first-use cost over max(SPIKE_MS, NOISE_X medians) that also sits that far above
## the median frame, in a window that made a node or compiled a pipeline.
## Run it on a GPU (jobq) for the drawn frames; headless it measures the script side only.

const DT := 1.0 / 60.0
const SPIKE_MS := 8.0  # ms over the median frame (and over the repeat) that counts as a first-cast hitch
# a first-use cost must also be over NOISE_X medians: load noise scales with the frame (w2 quiet: median 10-14 ms,
# noise up to 1.1x; a bisect at load 40: median 19-33 ms, noise up to 2.0x); real hitches were 183-260 ms
const NOISE_X := 3.0
const WINDOW := 24  # frames watched after a press (shots that land, a fuse's late burst)
const SETTLE := 60  # frames between presses: effects of the last slot die down
const SLOTS := ["lmb", "rmb", "e", "r", "dash", "q"]
const TARGET_DIST := 6.0  # m, the dummy in front of the Hunter
const PASSES := 3  # the first press, then repeats (the cheaper repeat is the baseline: load noise)

var bad := 0
var rows: Array = []
var hit := false  # the target lost health in this window
var made := {}  # node kind -> how many entered the tree in this window


func run(main: Node) -> void:
	var tree := main.get_tree()
	OS.low_processor_usage_mode = false  # (headless sleeps 6.9 ms a frame otherwise: a floor under every time)
	OS.low_processor_usage_mode_sleep_usec = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["classes"] = ClassUnlock.legacy()
	Save.d = d
	var gloves: Array = Gear.ids_for(0).filter(func(g): return Gear.active(String(g)))
	gloves.sort()
	var only := ""  # --first-cast-check=gunslinger,mage: just those
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--first-cast-check="):
			only = String(a).get_slice("=", 1)
	for i in Arch.ORDER.size():
		var ak: String = Arch.ORDER[i]
		if only != "" and not only.split(",").has(ak):
			continue
		await _hunter(main, ak, String(gloves[i % gloves.size()]) if not gloves.is_empty() else "")
	print("FIRSTCAST %-10s %-5s %-6s %7s %7s %7s %7s" % ["hunter", "slot", "went", "median", "first", "repeat", "cost"])
	for r in rows:
		print("FIRSTCAST %-10s %-5s %-10s %7.1f %7.1f %7.1f %7.1f %s" % r)
	print("FIRSTCAST DONE, %d slots, failures: %d" % [rows.size(), bad])
	tree.quit(1 if bad > 0 else 0)


func _hunter(main: Node, ak: String, glove: String) -> void:
	var tree := main.get_tree()
	var m := Match.new()
	main.add_child(m)
	await m.start(
		{
			"training": true,
			"practice": true,
			"teams": 1,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"no_drop": true,
			"cls": Arch.weight(ak),
			"arch": ak,
			"weapon": Arch.signature(ak)
		}
	)
	m.set_process(false)
	await m.warm_up()
	m.set_process(false)
	var p: Hunter = m.player
	p.unlock_all()
	p.lvl = 6
	p.slot_lv["ult"] = 1
	if p.ak:
		p.ak.cd_off = true
	if glove != "":
		p.gear[0] = {"id": glove, "rar": 1}
	var at := p.pos + Vector3(TARGET_DIST, 0, 0)
	var t: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, at, {"arch": "none"})
	t.max_hp = 1e6
	t.hp = t.max_hp
	for i in 15:  # the yard keeps 4 dummies up, one every 2 s: all of them before measuring
		if m.mobs.filter(func(x): return not x.dead).size() >= 4:
			break
		await _frames(m, p, t, SETTLE * 2, "")
	var times: Array = await _frames(m, p, t, SETTLE * 2, "")
	times.sort()
	var med: float = times[int(times.size() / 2.0)]
	var first := {}
	var rep := {}
	tree.node_added.connect(_made)
	for pass_i in PASSES:
		for s in SLOTS:
			if m.hud:
				m.hud.slot_fx.clear()
			hit = false
			made.clear()
			var pipes := DashPace.pipelines()
			var w: float = (await _frames(m, p, t, WINDOW, s)).max()
			pipes = DashPace.pipelines() - pipes
			if pass_i == 0:
				first[s] = [w, _went(m), "%d pipelines; %s" % [pipes, _summary()]]
			else:
				rep[s] = minf(float(rep.get(s, w)), w)
			await _frames(m, p, t, SETTLE, "")
	var span := []
	if _lays_bridge(glove):
		span = await _span(m, p, t)
	tree.node_added.disconnect(_made)
	for s in SLOTS:
		_row(ak, s, first[s][1], med, first[s][0], rep[s], first[s][2])
	if not span.is_empty():
		_row(ak, "span", span[0], med, span[1], span[2], span[3])
	m.queue_free()
	await tree.process_frame


func _lays_bridge(glove: String) -> bool:
	return Gear.ALL.get(glove, {}).get("effects", []).any(func(e): return String(e.get("type", "")) == "bridge")


## A bridge glove only lays slabs over abyss, and the yard has none in front: a strip of it is cut between
## the Hunter and the target, then the glove is cast PASSES times, each after the last span melted.
## Returns [went, first, repeat, what] for a "span" row.
func _span(m: Match, p: Hunter, t_v: Hunter) -> Array:
	var w: World = m.world
	for dx in range(2, 5):
		for dz in range(-2, 3):
			var tx := int(floor(p.pos.x)) + dx
			var tz := int(floor(p.pos.z)) + dz
			if w.inb(tx, tz):
				w.kind[w.idx(tx, tz)] = World.T_VOID
	var out := ["-", 0.0, INF, ""]
	for pass_i in PASSES:
		made.clear()
		var pipes := DashPace.pipelines()
		var t: float = (await _frames(m, p, t_v, WINDOW, "q")).max()
		if pass_i == 0:
			var what := "%d pipelines; %s" % [DashPace.pipelines() - pipes, _summary()]
			out = ["laid" if not m.verbs.terrain.is_empty() else "-", t, INF, what]
		else:
			out[2] = minf(float(out[2]), t)
		for i in 30:  # until the span melts (the frost glove's lasts 7 s)
			if m.verbs.terrain.is_empty():
				break
			await _frames(m, p, t_v, SETTLE, "")
	return out


func _row(ak: String, s: String, went: String, med: float, f: float, rep: float, what: String) -> void:
	var cost := f - rep
	var over := maxf(SPIKE_MS, NOISE_X * med)  # (a bisect on a box at load 40, flat SPIKE_MS: 32 false FAILs)
	# nothing made, nothing compiled: a slow frame with no cause is the host, not the first cast
	var traced := what != "0 pipelines; "
	var hitch := cost > over and f - med > over and traced
	if hitch:
		bad += 1
	rows.append([ak, s, went, med, f, rep, cost, ("FAIL: " + what) if hitch else "ok"])


## Counts a node that entered the tree, by its kind and the nearest scripted node above it (who made it).
func _made(n: Node) -> void:
	var key := n.get_class()
	if n.get_script():
		key = String((n.get_script() as Script).resource_path.get_file())
	var up := n.get_parent()
	while up and up.get_script() == null:
		up = up.get_parent()
	if up:
		key += "@" + String((up.get_script() as Script).resource_path.get_file().get_basename())
	made[key] = int(made.get(key, 0)) + 1


## The nodes a window added, most first (for a FAIL line: what to pool or warm).
func _summary() -> String:
	var ks: Array = made.keys()
	ks.sort_custom(func(a, b): return int(made[a]) > int(made[b]))
	return ", ".join(ks.slice(0, 8).map(func(k): return "%s x%d" % [k, made[k]]))


## How a press went, for the table: "cast" (the HUD's slot flash), "hit" (the target lost
## health), "deny", or "-" (nothing seen: the window may not have used the slot at all).
func _went(m: Match) -> String:
	var kinds: Array = m.hud.slot_fx.values().map(func(v): return String(v["kind"])) if m.hud else []
	if kinds.has("cast"):
		return "cast"
	if hit:
		return "hit"
	return "deny" if kinds.has("deny") else "-"


## Steps `n` frames (a step and a drawn frame each), pressing `slot` on the first, and returns each
## frame's wall time in ms. The yard's dummies can't die, so only the kit makes things.
func _frames(m: Match, p: Hunter, t: Hunter, n: int, slot: String) -> Array:
	var out: Array = []
	for i in n:
		for mb in m.mobs:
			mb.hp = mb.max_hp  # (the yard's dummies don't hit back; a dead one respawns)
		p.inp["aim"] = t.pos + Vector3(0, 0.9, 0)
		p.inp["aim_y"] = t.pos.y
		p.dashes = p.max_dashes()
		p.gear_cd[0] = 0.0
		_press(p, slot, i)
		var t0 := Time.get_ticks_usec()
		m.step(DT)
		await m.get_tree().process_frame
		out.append((Time.get_ticks_usec() - t0) / 1000.0)
		if t.hp < t.max_hp:
			hit = true
		t.hp = t.max_hp
	return out


## The keys of a slot as Match._gather_input sets them (R as HunterKeys takes it): LMB held 6 frames
## (charged shots fire on release), RMB held 2, the rest pressed once.
func _press(p: Hunter, slot: String, i: int) -> void:
	p.inp["fire"] = slot == "lmb" and i < 6
	p.inp["sec_hold"] = slot == "rmb" and i < 2
	p.inp["dash_down"] = slot == "dash" and i < 2
	if i > 0:
		return
	if p.ak:
		for key in p.ak.cd:
			p.ak.cd[key] = 0.0
	match slot:
		"rmb":
			p.inp["sec"] = true
		"e":
			p.inp["sig"] = true
		"r":
			HunterKeys.ult_pressed(p)  # (R goes straight to the kit, not through inp)
		"dash":
			p.inp["dash"] = true
		"q":
			p.inp["gear1"] = true
