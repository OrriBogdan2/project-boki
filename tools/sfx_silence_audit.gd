extends RefCounted
## --sfx-silence-audit: which game events play no sound, or only a shared one (docs/AUDIO.md, "Silence audit").
## Runs a seeded 10-trio bot match headless (Sfx.cue_log on) and matches each event (hit, status, cast, knock,
## out, level, pickup, recast window, exit step, Boki state, extract) to the cues played near it in the same or
## next step. Prints the events ranked by how often they got no cue ("none") or only shared ones ("shared").
## Matching is by place and time, so "shared" can include a neighbour's cue; "none" is solid. A cue that is
## culled by distance still counts as played here: this audit is about wiring, not hearing range.
## "MUTED name": a cue Sfx.skip held back (a Hero's own replaces it) or with no file; MISSING lines are the latter.
## Options: --audit-secs=<match seconds> (default 150), --audit-seed=<n> (default 31), --audit-out=<tsv path>,
## --audit-arch=<id> (the autoplay player is that archetype; default the save's) and --audit-throw (the player's own
## Boki is thrown at the nearest rival every few seconds and called back: its [you] rows get real samples).

const SECS := 150.0
const SEED := 31
const NEAR := 6.0       # m: a cue this close to an event's place belongs to it
const WINDOW := 2       # steps an event waits for its cue (its own step and the next)
const THROW_EVERY := 5.0    # s between the player's throws (--audit-throw)
const THROW_REACH := 10.0   # m: how far toward the nearest rival the Boki is thrown
const SHOW := 40        # rows printed
const NOISE := ["step", "wisp_hum", "glider_wind"]     # constant background cues, never an event's own

var fails := 0
var shared := {}        # cue name -> true: the generic names no sound set owns
var tally := {}         # key -> {n, none, shared, cues: {name: n}}
var pending: Array = []
var prev := {}          # hunter id -> last polled state
var prev_exit := {}
var step_events: Array = []
var missing := {}       # cue name -> times asked for with no sound file anywhere

func ok(cond: bool, what: String) -> void:
	print("SILENCE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1

func _arg(flag: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with(flag + "="):
			return String(a).substr(flag.length() + 1)
	return fallback

func _load_shared() -> void:
	var owned := {}
	for f in DirAccess.get_files_at("res://content/sfx"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/" + f))
			if d is Dictionary:
				for n in d.get("sounds", {}):
					owned[n] = true
	for n in Sfx.NAMES + Sfx.VOICES:
		if not owned.has(n):
			shared[n] = true

func _who(e) -> String:
	if e is Hunter:
		return String(e.arch) if e.arch != "" else "classkit"
	if e is Ent and e.get_script() != null:
		return String(e.get_script().get_global_name()).to_snake_case()
	return "world"

## What a hit landed on, for the key: a hunter, a Boki ("kin"), a monster or the rest.
func _target_class(e) -> String:
	if e is Hunter: return "hunter"
	if e is Kin: return "kin"
	if e is Mob: return "mob"
	return "other"

func _at(e) -> Vector3:
	return e.pos if e is Ent else Vector3.INF

func _add(kind: String, detail: String, who, places: Array) -> void:
	var m: Match = _m
	var mine: bool = who == m.player or places.has(m.player)
	var ps: Array = []
	for p in places:
		ps.append(_at(p) if p is Ent else p)
	var key := "%s %s [%s]" % [kind, detail, "you" if mine else "other"]
	step_events.append({"key": key, "ps": ps, "mine": mine, "cues": [], "age": 0})

var _m: Match

func _on_hit(attacker: Node, target: Node, _amount: float, tags: Array) -> void:
	_add("hit", "%s>%s %s" % [_who(attacker), _target_class(target), ",".join(tags)], attacker, [attacker, target])

func _on_cast(caster: Node, id: String, slot: String) -> void:
	_add("cast", "%s %s" % [slot, id], caster, [caster])

func _on_status(target: Node, status: String, by: Node, _t: float) -> void:
	_add("status", "%s on %s" % [status, _who(target)], by, [target])

func _on_kin(kin: Node, owner_h: Node) -> void:
	_add("boki", "%s" % kin.get("state"), owner_h, [owner_h])

func _poll() -> void:
	for h: Hunter in _m.hunters:
		var id := h.get_instance_id()
		var belt := 0
		for b in h.belt:
			belt += int(b.get("n", 0))
		var kin_state: String = h.kin.state if h.kin is Kin else ""
		var recast: bool = h.ak != null and not h.ak.recast_window().is_empty()
		var s := {"downed": h.downed, "out": h.out, "extracted": h.extracted, "lvl": h.lvl, "belt": belt,
			"recast": recast, "kin": kin_state, "arch": _who(h)}
		var p: Dictionary = prev.get(id, s)
		var who := _who(h)
		if s["downed"] and not p["downed"]: _add("knock", who, h, [h])
		if s["out"] and not p["out"]: _add("out", who, h, [h])
		if s["extracted"] and not p["extracted"]: _add("extract", who, h, [h])
		if s["lvl"] > p["lvl"]: _add("level", who, h, [h])
		if s["belt"] > p["belt"]: _add("pickup", who, h, [h])
		if s["recast"] != p["recast"]: _add("recast", "%s %s" % [who, "open" if s["recast"] else "close"], h, [h])
		if s["kin"] != p["kin"] and p["kin"] != "": _add("boki", "%s>%s" % [p["kin"], s["kin"]], h, [h])
		prev[id] = s
	for x in _m.exits.list:
		var st := String(x.get("state", ""))
		if prev_exit.has(x["pos"]) and prev_exit[x["pos"]] != st:
			_add("exit", "%s>%s" % [x.get("kind", "?"), st], null, [x["pos"]])
		prev_exit[x["pos"]] = st

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _match_cues(new_cues: Array) -> void:
	for c in new_cues:
		if not c[2] and not Sfx.ensure(String(c[0])):
			missing[c[0]] = int(missing.get(c[0], 0)) + 1
	for ev in pending:
		for c in new_cues:
			var n := String(c[0])
			if NOISE.any(func(w): return n.contains(w)):
				continue
			var near: bool = false
			if c[1] == null:
				near = ev["mine"]
			else:
				near = ev["ps"].any(func(p): return p is Vector3 and _flat(p, c[1]) <= NEAR)
			if near:
				ev["cues"].append(n if c[2] else "MUTED " + n)
		ev["age"] += 1
	var keep: Array = []
	for ev in pending:
		if ev["age"] >= WINDOW:
			_tally(ev)
		else:
			keep.append(ev)
	pending = keep

func _tally(ev: Dictionary) -> void:
	var t: Dictionary = tally.get(ev["key"], {"n": 0, "none": 0, "shared": 0, "cues": {}})
	t["n"] += 1
	var own: Array = ev["cues"].filter(func(n): return not shared.has(n) and not n.begins_with("MUTED"))
	if ev["cues"].is_empty():
		t["none"] += 1
	elif own.is_empty():
		t["shared"] += 1
	for n in ev["cues"]:
		t["cues"][n] = int(t["cues"].get(n, 0)) + 1
	tally[ev["key"]] = t

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	_load_shared()
	ok(Sfx.cue_log == null, "the cue log is off by default")
	var secs := float(_arg("--audit-secs", str(SECS)))
	var opts := {"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": int(_arg("--audit-seed", str(SEED))),
		"no_drop": true, "autoplay": true}
	var arch := _arg("--audit-arch", "")
	ok(arch == "" or Arch.exists(arch), "the player's archetype '%s' exists" % arch)
	if Arch.exists(arch):
		opts.merge({"arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch)}, true)
	var throw := OS.get_cmdline_user_args().has("--audit-throw")
	if throw:
		opts["demo_kin"] = "cindle"         # (a fresh save has no Boki for the player)
	_m = Match.new()
	main.add_child(_m)
	_m.start(opts)
	_m.set_process(false)
	ok(_m.hunters.size() == 30, "10 trios: %d hunters" % _m.hunters.size())
	CombatBus.hit_landed.connect(_on_hit)
	CombatBus.ability_used.connect(_on_cast)
	CombatBus.status_applied.connect(_on_status)
	CombatBus.kin_thrown.connect(_on_kin)
	CombatBus.kin_recalled.connect(_on_kin)
	Sfx.cue_log = []
	var steps := int(secs / Match.DT)
	for i in steps:
		_m.step(Match.DT)
		if throw and i % int(THROW_EVERY / Match.DT) == 0:
			_throw_own()
		_poll()
		pending.append_array(step_events)
		step_events = []
		_match_cues(Sfx.cue_log)
		Sfx.cue_log = []
		if _m.over or i % 600 == 599:
			await main.get_tree().process_frame
		if _m.over:
			break
	for ev in pending:
		_tally(ev)
	Sfx.cue_log = null
	print("SILENCE player %s, archetypes in the match: %s" % [_who(_m.player), _arch_counts()])
	_fixes()
	_report()
	print("SILENCE CHECK DONE, failures: ", fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## --audit-throw: the player's Boki leaves the shoulder toward the nearest rival; once out, it is called back.
func _throw_own() -> void:
	var p: Hunter = _m.player
	var k: Kin = p.kin
	if p.out or p.downed or k == null:
		return
	if k.state == "active" and KinCommand.can_recall(p):
		KinCommand.call_back(p)
	elif k.state == "shoulder":
		var rivals: Array = _m.hunters.filter(func(x: Hunter): return x.team != p.team and not x.out)
		rivals.sort_custom(func(a: Hunter, b: Hunter): return _flat(a.pos, p.pos) < _flat(b.pos, p.pos))
		var to: Vector3 = (rivals[0].pos - p.pos) if not rivals.is_empty() else Vector3.FORWARD
		to.y = 0.0
		k.throw_to(p.pos + to.normalized() * THROW_REACH)

## Hunters per archetype, to pick the one a seed covers least ("ashwick 0" is absent from the list).
func _arch_counts() -> String:
	var n := {}
	for h: Hunter in _m.hunters:
		n[_who(h)] = int(n.get(_who(h), 0)) + 1
	return ", ".join(n.keys().map(func(a): return "%s %d" % [a, n[a]]))

## The cues the audit's first fixes added, each probed on its own (docs/AUDIO.md, Silence audit).
func _cues_of(probe: Callable) -> Array:
	Sfx.cue_log = []
	probe.call()
	var names: Array = Sfx.cue_log.map(func(c): return c[0])
	Sfx.cue_log = null
	return names

func _fixes() -> void:
	for kind in Data.MOBS:      # (the boss and the stones with no strike have no wind-up call)
		if Data.MOBS[kind]["attack"] in ["none", "boss"]:
			continue
		ok(Sfx.ensure("v_" + String(kind).trim_prefix("bl_")), "mob %s has a wind-up voice" % kind)
	var hs: Array = _m.hunters.filter(func(x): return x != _m.player and x.kin is Kin and not x.out)
	var a: Hunter = hs[0]
	var b: Hunter = hs[1]
	var k: Kin = a.kin
	ok("recall" in _cues_of(func(): KinFollow.leap(k, k.pos, "side")), "a Boki's own hop back plays the recall cue")
	var ordered := _cues_of(func(): KinFollow.leap(k, k.pos, "side", true))
	ok(not "recall" in ordered, "...but not on an ordered recall (that plays its own)")
	ok("kin_unsure" in _cues_of(func(): KinDowned.begin(k, false)), "a Boki going down cries in its voice")
	b.pos = _m.player.pos + Vector3(3, 0, 0)
	var plain := _cues_of(func(): Juice.hit(_m, b, a, 10.0, {}, false, false))
	var crit := _cues_of(func(): Juice.hit(_m, b, a, 10.0, {}, true, false))
	ok("hit" in plain, "a hit between two others has an impact cue")
	ok("crit" in crit, "...and a crit its crit cue")
	ok("pickup" in _cues_of(func(): Juice.rival_pickup(_m, a)), "another hunter's pickup is heard")
	_raid_rows()
	ok(missing.is_empty(), "no cue the match asked for lacks a sound file (%s)" % [missing.keys()])

## Heart Raid's events (scripts/match/raid_sfx.gd), each on a Nightmare raid of its own: the cue its event plays.
func _raid_rows() -> void:
	var o := HeartRaid.opts(1, "nightmare")
	o.merge({"seed": 23, "tier": 0, "no_drop": true, "sim_keep": true})
	var rm := Match.new()
	_m.get_parent().add_child(rm)
	rm.start(o)
	rm.set_process(false)
	var rd: HeartRaid = rm.heart_raid
	rd.audio.update()      # (the first look only notes the state)
	var run := func(n: int): for i in n: rm.step(Match.DT)
	var ticks := _cues_of(func():
		rd.next_wave_t = rm.sess_time() + float(RaidSfx.TICK_S) - 0.5
		rd.gates.mark(0, rd.next_wave_t)
		rd.gates.show_marks()
		run.call(int(0.6 / Match.DT)))
	var n_ticks := ticks.count("raid_gate_tick")
	var gates_n := rd.gates.marks.size()
	ok(n_ticks >= gates_n, "raid: every marked gate ticks (%d for %d gates)" % [n_ticks, gates_n])
	var wave := _cues_of(func():
		rd.wave += 1
		rd.audio.update())
	ok("raid_wave_open" in wave, "raid: a wave opening has its sting")
	var rise := _cues_of(func():
		rd._spawn_boss()
		rd.audio.update())
	ok("raid_boss_rise" in rise, "raid: the boss rising has its sting")
	var b := rd.boss as Boss
	ok("raid_phase" in _cues_of(func(): b._phase_up(1)), "raid: a boss phase change has its cue")
	ok("raid_rockfall_warn" in _cues_of(func(): b._atk_rockfall()), "raid: the Nightmare rockfall warns")
	rm.queue_free()

func _bad(t: Dictionary) -> int:
	return int(t["none"]) + int(t["shared"])

func _report() -> void:
	var rows: Array = []
	var total := 0
	for k in tally:
		var t: Dictionary = tally[k]
		total += int(t["n"])
		rows.append([k, t])
	ok(total > 0, "%d events seen" % total)
	var kinds := {}
	for r in rows:
		kinds[String(r[0]).get_slice(" ", 0)] = true
	ok(kinds.size() >= 5, "event kinds seen: %s" % [", ".join(kinds.keys())])
	rows.sort_custom(func(x, y): return _bad(x[1]) > _bad(y[1]))
	var lines: Array = []
	for r in rows:
		var t: Dictionary = r[1]
		var cues: Array = t["cues"].keys()
		cues.sort_custom(func(a, b): return t["cues"][a] > t["cues"][b])
		lines.append("%d\t%d\t%d\t%s\t%s" % [t["none"] + t["shared"], t["none"], t["n"], r[0],
			", ".join(cues.slice(0, 4).map(func(n): return "%s x%d" % [n, t["cues"][n]]))])
	var shown := 0
	for l in lines:
		if shown < SHOW and int(String(l).get_slice("\t", 0)) > 0:
			print("SILENCE ROW (bad, none, n, event, top cues): ", l)
			shown += 1
	for n in missing:
		print("SILENCE MISSING cue with no sound file: %s x%d" % [n, missing[n]])
	var out := _arg("--audit-out", "")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("bad\tnone\tn\tevent\ttop cues\n" + "\n".join(lines) + "\n")
