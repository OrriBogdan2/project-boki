extends "res://tools/parity_reel.gd"
## --motley-reel --shots-dir=<dir> [--reel-only=<part>]: Motley's E and Shift on the Hollow Crown (it has real
## ledges), at the match camera with the HUD and the key caps, for the owner's review: E with no marker on the
## ground (the E slot says E AGAIN), the bigger Trade swapping a dummy, and a Trade thrown at a cliff face that
## lands him on top. Frames go to <dir>/frames/NNNNN.jpg (run under jobq --needs gpu); REEL_MARK gives each part's
## first frame. Never writes the save.

const MOTLEY_PARTS := ["e", "trade", "ledge"]
const LEDGE_RISE := 2          # terraces the ledge stands over the ground he throws from (at least)

func parts() -> Array:
	return MOTLEY_PARTS

func run(main_node: Node) -> void:
	main = main_node
	who = "ostra"
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
		if arg.begins_with("--reel-only="): only = arg.substr(12)
	hero_name = who
	await _setup()
	_build_keys()
	frame_dir = dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frame_dir)
	P.lvl = 6
	for slot in P.slot_lv:
		P.slot_lv[slot] = 3
	for part: String in MOTLEY_PARTS:
		if only == "" or part == only:
			print("REEL_MARK %d %s" % [frames, part])
			await Callable(self, "_m_" + part).call()
	print("REEL_DONE %d frames in %s" % [frames, frame_dir])
	main.get_tree().quit(0)

func _setup() -> void:
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": true,
		"map": "hollowcrown", "arch": who, "cls": Arch.weight(who), "weapon": Arch.signature(who)}
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	P.unlock_all()
	home = _spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T:
			x.teleport(home + Vector3(-30, 0, 30))
	await _reset(7.0)

func _m_e() -> void:
	await _seg("E: the seed grows, no prompt on the ground; the E slot says E AGAIN", 5.0, func(t: float) -> void:
		P.inp["sig"] = _in(t, 0.2) or _in(t, 4.0))

func _m_trade() -> void:
	await _seg("Shift: a bigger lantern and circle (1.9 m), the dummy trades places", 3.2, func(t: float) -> void:
		P.inp["dash"] = _in(t, 0.3), 8.0)

## A cliff 4 m ahead: the cursor on its face, Shift, and he lands standing on top.
func _m_ledge() -> void:
	var c := _ledge()
	title.text = "Shift at a cliff face: he lands on top" if not c.is_empty() else "no ledge found"
	if c.is_empty():
		return
	T.teleport(home + Vector3(-30, 0, -30))
	home = c["start"]
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	cam_at = (c["start"] + c["aim"]) * 0.5
	_aim(c["aim"])
	await _go(4.0, func(t: float) -> void:
		_aim(c["aim"])
		P.inp["dash"] = _in(t, 0.6))
	print("REEL_LEDGE from y %.2f to %s" % [float(c["start"].y), str(P.pos)])
	P.inp["move"] = Vector2.ZERO
	cam_at = Vector3.ZERO

## A terrace edge facing +x, LEDGE_RISE+ terraces up, with 4 m of flat ground before it and room on top.
func _ledge() -> Dictionary:
	var W = m.world
	for z in range(4, W.h - 4):
		for x in range(6, W.w - 6):
			var lv := int(W.level[W.idx(x, z)])
			var ok := true
			for dx in range(-4, 1):
				var i: int = W.idx(x + dx, z)
				ok = ok and W.kind[i] == World.T_GROUND and int(W.level[i]) == lv and not W.stairs.has(i)
			var top := int(W.level[W.idx(x + 1, z)])
			for dx in range(1, 4):
				var j: int = W.idx(x + dx, z)
				ok = ok and W.kind[j] == World.T_GROUND and int(W.level[j]) == top and not W.stairs.has(j)
			if ok and top - lv >= LEDGE_RISE and top - lv <= LEDGE_RISE + 3:
				var y := lv * World.LEVEL
				return {"start": Vector3(x - 3.5, y, z + 0.5), "aim": Vector3(x + 0.8, y, z + 0.5)}
	return {}
