extends RefCounted
## --garden-nav-check: six Boki, every plaything, a stream and the house on one base for 10 in-game minutes, stepped
## at 4x the 1/16 s frame (0.25 s a step, no rendering). It counts every Boki that is stuck (wants to move and
## has made no progress for 3 s), two Boki sitting on each other for 3 s, and any Boki standing inside the house,
## a toy, water or any other block it can't enter. Zero stuck and zero inside is the pass bar; overlaps are printed
## and counted (two Boki sharing a toy or a pile may brush), not failed. Never touches the real save.
## `--nav-zone=<id>` runs it in that garden zone (garden_zones.json) instead of Bramblebank.

const SIM_SECS := 600.0        # s of game time (10 in-game minutes)
const DT := 0.25               # s per step
const STUCK_SECS := 3.0        # s a Boki may want to move without getting anywhere
const PROGRESS := 0.12         # m moved in a step window that counts as progress
const WANT_DIST := 0.5         # m: a goal farther than this is a wish to move
const OVERLAP_K := 0.6         # of the two body radii: closer than this is overlapping
const CAST := ["zapple", "puddlet", "cindle", "kilnbadger", "lodestick", "marchleaf"]
const SEED := 5

var zone := ""         # --nav-zone=: the zone to sweep ("" the start zone)
var bad := 0
var main: Node
var home
var track := {}        # uid -> {at: Vector3, still: s, why: String}
var lap := {}          # "uidA/uidB" -> s overlapped
var overlaps := 0     # two Boki on top of each other for STUCK_SECS (printed, not failed)
var waded := {}        # uid -> true: it stood in the stream at some point
var logged := {}       # one line per cause, not per step

func ok(cond: bool, what: String) -> void:
	print("GARDENNAV %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _save() -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in CAST.size():
		var rec := Save.new_kin(CAST[i], "B%d" % i)
		Care.ensure(rec)
		if zone != "":
			rec["zone"] = zone
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["gems"] = 1000
	HomeLayout.new_fs(d, SEED)
	if zone != "":
		d["zones"][zone] = {"open": true}
	Save.d = d

## The base's Home, in the zone if there is one.
func _open_home() -> Node:
	if zone == "":
		return await main._hb_home()
	var hm: Node = load("res://scripts/home/home.gd").new()
	hm.zone = zone
	main.add_child(hm)
	main.current = hm
	for i in 2:
		await main.get_tree().process_frame
	return hm

## Every plaything and the house on the built farm, round the landing.
func _stage() -> void:
	var land := HomeLayout.LANDING
	for id in Content.rules("toys")["toys"]:
		ok(not home.hg.demo_place(id, land + Vector3(0, 0, 3.0)).is_empty(), "%s placed" % id)
	ok(not home.hg.demo_place("house", land + Vector3(6.0, 0, -4.0)).is_empty(), "house placed")
	for x in range(int(land.x) - 8, int(land.x) + 9):      # a stream they wade (BokiWade) three tiles wide
		for z in range(int(land.z) - 7, int(land.z) - 4):
			home.hb.L()["water"][HomeLayout.key(x, z)] = 1
	home.hb.apply(false)
	home._sync_fixtures()
	home.ppos = land + Vector3(0, 0, 1.0)
	home.player.position = home.ppos
	for k in home.kins:
		k["pos"] = home.world.free_spot_near(land + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]

func _xz(p: Vector3) -> String:
	return "(%.1f,%.1f)" % [p.x, p.z]

func _note(key: String, line: String) -> void:
	if not logged.has(key):
		logged[key] = true
		print("GARDENNAV   %s" % line)

func _state(k: Dictionary) -> String:
	var s := String((k["life"] as Fsm).state_name()) if k.has("life") else ""
	for key in ["play", "eat", "fetch", "job", "chase", "going_in", "bath", "task"]:
		if k.has(key):
			s += "+" + key
	return s

## Is the Boki free to be still: asleep, held, indoors, playing at its toy or sulking.
func _resting(k: Dictionary) -> bool:
	if k.has("indoors") or k.get("busy", false) or KinAvoid.lying(k):
		return true
	var play: Variant = k.get("play")
	return play is Dictionary and play["phase"] == "play"

func _watch(t: float) -> int:
	var found := 0
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var tr: Dictionary = track.get(rec["uid"], {"at": k["pos"], "still": 0.0})
		var pos: Vector3 = k["pos"]
		var goal: Vector3 = k["goal"]
		var to := Vector2(goal.x - pos.x, goal.z - pos.z)
		var wants: bool = goal != Vector3.INF and to.length() > WANT_DIST and not _resting(k)
		if not wants or Vector2(pos.x - tr["at"].x, pos.z - tr["at"].z).length() > PROGRESS:
			tr = {"at": pos, "still": 0.0}
		else:
			tr["still"] = float(tr["still"]) + DT
			if float(tr["still"]) >= STUCK_SECS and not tr.has("hit"):
				tr["hit"] = true
				found += 1
				print("GARDENNAV STUCK t=%.0f %s at %s goal %s %s" % [t, rec["name"], _xz(pos), _xz(goal), _state(k)])
		track[rec["uid"]] = tr
		if k.get("wade", {}).get("in", false):
			waded[rec["uid"]] = true
		if not (k["node"] as Node3D).visible or k.has("indoors") or k.has("leap"):
			continue
		if home.world.occupy(pos.x, pos.z, 0.0, 0.0, true) != 0.0 or home.world.is_void(pos.x, pos.z):
			found += 1
			var line := "INSIDE t=%.0f %s at %s %s" % [t, rec["name"], _xz(pos), _state(k)]
			_note("in%s%s" % [rec["name"], _xz(pos)], line)
	overlaps += _overlaps(t)
	return found

func _overlaps(t: float) -> int:
	var found := 0
	var act: Array = home.kins.filter(func(o): return not (o.has("indoors") or o.has("leap") or o.get("busy", false)))
	act = act.filter(func(o): return (o["node"] as Node3D).visible)
	for i in act.size():
		for j in range(i + 1, act.size()):
			var a: Dictionary = act[i]
			var b: Dictionary = act[j]
			var key := "%s/%s" % [a["rec"]["uid"], b["rec"]["uid"]]
			var need: float = (home._kin_r(a) + home._kin_r(b)) * OVERLAP_K * home.life.pile(a, b)
			if Vector2(a["pos"].x - b["pos"].x, a["pos"].z - b["pos"].z).length() >= need:
				lap.erase(key)
				continue
			lap[key] = float(lap.get(key, 0.0)) + DT
			if float(lap[key]) >= STUCK_SECS and lap[key] < STUCK_SECS + DT:
				found += 1
				var who := "%s and %s" % [a["rec"]["name"], b["rec"]["name"]]
				print("GARDENNAV OVERLAP t=%.0f %s at %s %s / %s" % [t, who, _xz(a["pos"]), _state(a), _state(b)])
	return found

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(SEED)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nav-zone="):
			zone = a.substr(11)
	_save()
	home = await _open_home()
	ok(home.kins.size() == CAST.size() and home.life != null, "%d Boki on a base_mode farm" % home.kins.size())
	_stage()
	var cases := 0
	var t := 0.0
	while t < SIM_SECS:
		home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
		home._move_kin(DT)
		t += DT
		cases += _watch(t)
	ok(cases == 0, "no Boki stuck or inside a block in %.0f s (%d cases); %d overlaps" % [SIM_SECS, cases, overlaps])
	ok(not waded.is_empty(), "%d Boki waded through the stream and nobody stuck in it" % waded.size())
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("GARDENNAV DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
