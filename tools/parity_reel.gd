extends "res://tools/hero_vfx_reel.gd"
## --parity-reel --shots-dir=<dir> --reel-hero=<arch> [--reel-only=<part>]: one Hunter's whole move set in the
## Training Grounds against a dummy, at the match camera, for the parity reel (docs/parity_reel/): LMB tap and
## hold, RMB, E, R (each with a second press for the recast), a ground and an air dash, a glide and a mantle. A
## row of key caps along the bottom lights up with the keys being pressed. Frames go to <dir>/frames/NNNNN.jpg at
## FRAME_FPS (run it under jobq --needs gpu, which returns the out dir); cut a clip off the box:
##   ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg -c:v libx264 -crf 30 -pix_fmt yuv420p reel.mp4
## REEL_MARK lines give the frame each part starts on. Never writes the save.

const SEQUENCE := ["lmb_tap", "lmb_hold", "rmb", "e", "r", "dash_ground", "dash_air", "glide", "mantle"]
const FRAME_FPS := 30                   # saved frames per second (every 2nd step of the 60 Hz match)
const KEYS := ["W", "A", "S", "D", "LMB", "RMB", "E", "R", "Shift", "Space"]
const FAR := 12.0                       # m to the dummy for the moves that travel
const RIM_GAP := 4.0                    # m of island kept east of the far dummy
const STOP_GAP := 2.0                   # m short of the far dummy where the travel parts stop walking
const KEY_LIT_S := 0.18                 # s a key cap stays lit after its press, so a one-step tap is seen
const KEY_ON := Color(1.0, 0.82, 0.3)
const KEY_OFF := Color(0.1, 0.1, 0.14, 0.7)
const RIPOSTE_TD := 3.0                 # m to the dummy in Kael's R part (inside the 3.6 m cleave strip)
const RIPOSTE_HIT_T := 0.4              # s into the part the dummy swings: in the 0.65 s guard after the 0.2 s press
const RIPOSTE_HP_K := 0.6               # Kael's hp share at the start of his R part, so the heal shows
const CLOAK_TD := 3.6                   # m to the dummy in Cinder's E part: inside her 4.5 m pull
const DUMMY_HIT := 10.0                 # the dummy's blow, when its own weapon does not land in time
const ALLY_AT := Vector3(4.0, 0, -3.0)  # the downed ally dummy, from the spot (in Hearth Call's 12.6 m reach)

var lit := {}                           # key cap -> s left lit
var caps := {}                          # key cap -> its Label
var title: Label
var steps := 0
var r_down := false                     # R was pressed this step (it goes through HunterKeys, not inp)

func parts() -> Array:
	return SEQUENCE

func run(main_node: Node) -> void:
	main = main_node
	who = "juggernaut"
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--reel-hero="):
			who = arg.substr(12)
		if arg.begins_with("--reel-only="):
			only = arg.substr(12)
	hero_name = who
	Save.d["tutorial"][KitDrill.SAVE_KEY] = true     # no kit drill card under the title (Save.no_write is on)
	await _setup()
	_build_keys()
	frame_dir = dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frame_dir)
	P.lvl = 6
	for slot in P.slot_lv:
		P.slot_lv[slot] = 3
	for part: String in SEQUENCE:
		if only == "" or part == only:
			print("REEL_MARK %d %s" % [frames, part])
			await Callable(self, "_p_" + part).call()
	print("REEL_DONE %d frames in %s" % [frames, frame_dir])
	main.get_tree().quit(0)

# ------------------------------------------------------------------ key caps
func _build_keys() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -64.0
	row.offset_bottom = -16.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	for k: String in KEYS:
		caps[k] = _label(k, 22, row)
	title = _label("", 28, layer)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 14.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _label(words: String, px: int, parent: Node) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_OFF
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	l.add_theme_stylebox_override("normal", sb)
	parent.add_child(l)
	return l

## The caps lit by this step's inputs, held for KEY_LIT_S.
func _keys_update() -> void:
	var mv: Vector2 = P.inp["move"]
	var on := {"W": mv.y < -0.3, "S": mv.y > 0.3, "A": mv.x < -0.3, "D": mv.x > 0.3,
		"LMB": P.inp["fire"], "RMB": P.inp["sec"] or P.inp["sec_hold"], "E": P.inp["sig"], "R": r_down,
		"Shift": P.inp["dash"], "Space": P.inp["jump"]}
	r_down = false
	for k: String in KEYS:
		lit[k] = KEY_LIT_S if on[k] else maxf(0.0, float(lit.get(k, 0.0)) - DT)
		var sb: StyleBoxFlat = caps[k].get_theme_stylebox("normal")
		sb.bg_color = KEY_ON if lit[k] > 0.0 else KEY_OFF
		caps[k].add_theme_color_override("font_color", Color.BLACK if lit[k] > 0.0 else Color.WHITE)

func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	var keyed := func(t: float) -> void:
		if each.is_valid():
			each.call(t)
		if not caps.is_empty():
			_keys_update()
	await super._go(secs, keyed, marks, lead)

func _save_frame() -> void:
	steps += 1
	if steps % (60 / FRAME_FPS) == 0:
		super._save_frame()

# ------------------------------------------------------------------ the parts
## True while `t` is in the `secs` window that starts at `from` (a press is a short window).
func _in(t: float, from: float, secs := 0.1) -> bool:
	return t >= from and t < from + secs

func _seg(text: String, secs: float, each: Callable, td := 7.0) -> void:
	title.text = text
	await _reset(td)
	await _go(secs, func(t: float) -> void:
		_aim(T.pos)
		each.call(t))
	await _go(0.3)

func _p_lmb_tap() -> void:
	await _seg("LMB tap x3", 2.8, func(t: float) -> void:
		P.inp["fire"] = _in(t, 0.2) or _in(t, 1.0) or _in(t, 1.8))

func _p_lmb_hold() -> void:
	await _seg("LMB hold", 3.4, func(t: float) -> void:
		P.inp["fire"] = _in(t, 0.2, 2.4))

func _p_rmb() -> void:
	await _seg("RMB, then again", 4.0, func(t: float) -> void:
		P.inp["sec"] = _in(t, 0.2) or _in(t, 2.0)
		P.inp["sec_hold"] = _in(t, 0.2, 0.7) or _in(t, 2.0, 0.7))

func _p_e() -> void:
	if who == "ostra":
		await _e_brimseed()
		return
	await _seg("E, then the recast", 4.0, func(t: float) -> void:
		P.inp["sig"] = _in(t, 0.2) or _in(t, 1.8)
	, CLOAK_TD if who == "ashwick" else 7.0)

## Motley's Brimseed grows for its `grow` s: the recast waits until it is full size, so the whole growth shows.
func _e_brimseed() -> void:
	var grow := float(Arch.def(who)["e"]["grow"])
	var popped := [-1.0]
	await _seg("E, the seed grows full, then the recast", grow + 2.4, func(t: float) -> void:
		var full: bool = popped[0] < 0.0 and t > 0.5 and P.ak.seed_k() >= 1.0
		if full:
			popped[0] = t
		P.inp["sig"] = _in(t, 0.2) or full)
	print("REEL_BRIMSEED grow %.1f popped at %.2f s" % [grow, popped[0]])

func _p_r() -> void:
	P.ak.cd["x"] = 0.0
	if who == "juggernaut":
		await _r_riposte()
		return
	if who == "tender":
		await _r_hearth_call()
		return
	await _seg("R, then the recast", 6.0, _r_presses)

func _r_presses(t: float) -> void:
	if _at(t, 0.2) or _at(t, 2.6):
		r_down = true
		HunterKeys.ult_pressed(P)

## Kael's Gilded Riposte answers a hit: he starts hurt (so the cleave's heal shows), the dummy stands inside the
## cleave's strip and swings at him once in the guard (one plain hit, the Training Grounds dummy firing its own
## weapon, else a direct blow), so the guard blocks it and the cleave lands and heals.
func _r_riposte() -> void:
	P.hp = P.max_hp * RIPOSTE_HP_K
	var blow := [false]
	await _seg("R: a hit on the guard, then the cleave", 6.0, func(t: float) -> void:
		_r_presses(t)
		T.inp["aim"] = P.pos + Vector3(0, 0.9, 0)
		T.inp["fire"] = _in(t, RIPOSTE_HIT_T, DT * 1.5)
		if _at(t, RIPOSTE_HIT_T + 0.15) and int(P.ak.riposte.blocked) == 0:
			P.hurt(DUMMY_HIT, T, {"src": "melee"})       # its weapon missed or was slow: the blow itself
			blow[0] = true
	, RIPOSTE_TD)
	T.inp["fire"] = false
	var u = P.ak.riposte
	var by := "direct blow" if blow[0] else "its weapon"
	print("REEL_RIPOSTE blocked %d (%s) strikes %d healed %.0f" % [u.blocked, by, u.strikes, u.last_healed])

## Meeko's Hearth Call needs a teammate: a downed ally dummy (the Training Grounds dummy on her team) lies in
## reach; R tethers it, the tether heals it, and at the end it is pulled to her side and stood up.
func _r_hearth_call() -> void:
	var at := home + ALLY_AT
	if T2 == null:                      # (the rig's second dummy slot: _park_others leaves it in place)
		T2 = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
		T2.lives = 99
	var ally: Hunter = T2
	ally.teleport(at)
	ally.vel = Vector3.ZERO
	if not ally.downed:
		m.knock(ally, T, {})
	var hp0: float = ally.down_hp
	title.text = "R on a downed teammate"
	await _reset(7.0)
	ally.teleport(at)
	await _go(6.0, func(t: float) -> void:
		_aim(ally.pos)
		_r_presses(t))
	await _go(0.3)
	print("REEL_CALL calls %d rescues %d downed %s down_hp %.0f" % [P.ak.stats["calls"], P.ak.stats["rescues"],
			ally.downed, hp0])
	ally.teleport(home + Vector3(-30, 0, 30))
	T2 = null

func _p_dash_ground() -> void:
	var dash := func(t: float) -> void:
		P.inp["move"] = Vector2(-1, 0) if _in(t, 1.2, 0.2) else _toward_far(t)
		P.inp["dash"] = _in(t, 0.3) or _in(t, 1.3)
	await _travel("Dash on the ground, there and back", 3.0, dash)

func _p_dash_air() -> void:
	var dash := func(t: float) -> void:
		P.inp["move"] = _toward_far(t)
		P.inp["jump"] = _in(t, 0.2)
		P.inp["dash"] = _in(t, 0.55)
	await _travel("Jump, then dash in the air", 3.0, dash)

func _p_glide() -> void:
	var glide := func(t: float) -> void:
		P.inp["move"] = Vector2.from_angle(t * 1.5) if t > 0.3 else Vector2.ZERO
		P.inp["jump"] = _in(t, 0.2, 3.4)
	await _travel("Jump and hold Space: glide", 4.2, glide)

## A travel part: the dummy FAR m east of where it starts, with RIM_GAP m of island past it. The Training
## Grounds spot sits near the island's east rim, so the part starts that much west of the spot. The second
## ground dash comes back west: two dashes east are longer than the island for the long dashes (Kael's ~14 m).
func _travel(text: String, secs: float, each: Callable) -> void:
	var back := maxf(0.0, FAR + RIM_GAP - _east_run())
	home.x -= back
	await _seg(text, secs, each, FAR)
	var W = m.world
	var on_ground: bool = W.kind[W.idx(int(P.pos.x), int(P.pos.z))] == World.T_GROUND
	print("REEL_TRAVEL %s start %.1f m west of the spot, ends %.1f m east of start, drop %.1f m, on ground %s"
			% [title.text, back, P.pos.x - home.x, home.y - P.pos.y, on_ground])
	home.x += back

## Whole metres of ground at the spot's level east of the spot.
func _east_run() -> float:
	var W = m.world
	var lv := int(W.level[W.idx(int(home.x), int(home.z))])
	var run := 0
	while run < 40:
		var i: int = W.idx(int(home.x) + run + 1, int(home.z))
		if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv:
			break
		run += 1
	return float(run)

## East, towards the far dummy, until 2.2 s in or STOP_GAP short of it.
func _toward_far(t: float) -> Vector2:
	return Vector2(1, 0) if t < 2.2 and P.pos.x < T.pos.x - STOP_GAP else Vector2.ZERO

## The Training Grounds has no terrace to run into, so the mantle is an island rim: dropped just below it, moving
## in, the Hunter catches the lip and comes over (as --cliff-mantle-check's "abyss" case).
func _p_mantle() -> void:
	var chk = load("res://tools/cliff_mantle_check.gd").new()
	chk.m = m
	chk.w = m.world
	chk.h = P
	var rims: Array = chk._rims()
	if rims.is_empty():
		print("REEL_MANTLE no rim")
		return
	var f: Dictionary = rims[rims.size() / 2]
	var dv := Vector2(f["d"])
	var a: Vector2i = f["a"]
	var face := Vector2(a.x + 0.5, a.y + 0.5) + dv * 0.5
	var top := float(f["la"] + f["rise"]) * World.LEVEL
	title.text = "Mantle the island rim"
	chk._setup(f, "abyss", face, dv, top)
	var ahead := Vector3(face.x + dv.x * 4.0, top + 0.9, face.y + dv.y * 4.0)
	var climb := func(_t: float) -> void:
		P.inp["move"] = dv
		P.inp["aim"] = ahead
	await _go(2.4, climb)
