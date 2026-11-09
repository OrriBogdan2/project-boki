extends RefCounted
## --knock-fall-shots --heroes=a,b,c,d --shots-dir=<dir>: a strip of Hunters going down (docs/ANIM_QUALITY.md).
## One row per Hunter, one cell per moment of the fall (the hero plays its fall clip, then the Wisp), cropped
## close, plus the head's height at each moment (KNOCKFALL lines, m above the feet). Needs a renderer for the
## picture; the numbers print headless too.

const DT := 1.0 / 60.0
var moments := [0.0, 0.1, 0.2, 0.3, 0.4, 0.55]    # s after the knock (--moments=a,b,c to change)
const CELL := Vector2i(260, 320)
const SETTLE := 0.5                                  # s the Hunters stand before the knock (landing from the teleport)
const SPACING := 4.0                                # m between Hunters
const ZOOM := 0.62                                   # camera zoom for the close crop

var main: Node
var m: Match
var ids: Array = []
var dir := ""
var centre := Vector3.ZERO      # what the camera frames: the middle of the row
var elim := ""      # --elim=direct|wisp: print how the body hands over after an elimination instead of the strip
var clip := ""      # --clip=<name>: play this clip as the death (and so the fall) instead, to compare candidates

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--moments="):
			moments = Array(String(a).substr(10).split(",")).map(func(x): return float(x))
		if String(a).begins_with("--elim="):
			elim = String(a).substr(7)
		if String(a).begins_with("--clip="):
			clip = String(a).substr(7)
		if String(a).begins_with("--heroes="):
			ids = String(a).substr(9).split(",")
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var strip := Image.create_empty(CELL.x * moments.size(), CELL.y * ids.size(), false, Image.FORMAT_RGB8)
	var foe: Hunter = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	var hs: Array = []
	for i in ids.size():
		var h: Hunter = m.hunters[i]
		h.reclass(Arch.weight(ids[i]), ids[i])
		h.hp = h.max_hp
		h.ctrl = "idle"      # reclass can hand it back to the bot
		h.teleport(centre + Vector3((i - (ids.size() - 1) * 0.5) * SPACING, 0, 0))
		hs.append(h)
		if clip != "":
			WardenClips.data(WardenGlb.art(h.arch))["states"]["dead"] = clip
	await _go(SETTLE)
	if elim != "":
		await _eliminate(hs, foe)
		return
	var heads := {}
	var t := 0.0
	for k in moments.size():
		if k == 0:
			for h in hs:
				m.knock(h, foe, {})
				h.down_hp = 1e6
		while t < float(moments[k]) - 1e-4:
			await _step()
			t += DT
		for i in hs.size():
			_cell(strip, hs[i], k, i)
			heads[i] = heads.get(i, []) + [snappedf(_head_y(hs[i]), 0.01)]
	for i in hs.size():
		print("KNOCKFALL %s head_y %s" % [ids[i], heads[i]])
	strip.save_png(dir.path_join("fall_%s.png" % "_".join(ids)))
	main.get_tree().quit(0)

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := m.world.random_ground()
	m.player.teleport(spot)
	centre = spot
	if m.hud:
		m.hud.visible = false      # no panels over the bodies
	m.cam.zoom_to = ZOOM
	m.cam.zoom = ZOOM
	for h in m.hunters:
		if h != m.player:
			h.teleport(spot + Vector3(30, 0, 0))

func _step() -> void:
	m.step(DT)
	m.cam.snap(centre)
	for h in m.hunters:
		h.render(DT, 1.0)
	await main.get_tree().process_frame

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await _step()
		t += DT

## Height of the head bone above the hunter's feet (the hero hidden under a Wisp reads as the pose it left).
func _head_y(h: Hunter) -> float:
	for sk in h.model.find_children("*", "Skeleton3D", true, false):
		var b := (sk as Skeleton3D).find_bone("head")
		if b >= 0:
			return ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(b)).origin.y - h.pos.y
	return -1.0

func _cell(strip: Image, h: Hunter, col: int, row: int) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if img == null:
		return
	var p := m.cam.unproject_position(h.pos + Vector3(0, 0.9, 0))
	var r := Rect2i(Vector2i(p) - CELL / 2, CELL)
	strip.blit_rect(img, r, Vector2i(col * CELL.x, row * CELL.y))

## Eliminates the Hunters (straight from standing, or after a knock turned them into Wisps) and prints, every
## 0.2 s, whether the body shows and which clip it plays (ELIM lines).
func _eliminate(hs: Array, foe: Hunter) -> void:
	if elim == "wisp":
		for h in hs:
			m.knock(h, foe, {})
			h.down_hp = 1e6
		await _go(0.8)
	for h in hs:
		m.eliminate(h, foe, "bleed")
	var seen := {}
	var t := 0.0
	while t < 1.8:
		for i in hs.size():
			var clips := (hs[i].model.get_node("Warden/Sync").get("clips")) as WardenClips
			var shown := "1" if hs[i].visible else "0"
			seen[i] = seen.get(i, []) + [shown + ":" + (clips.cur if clips else "")]
		for k in 12:
			await _step()
			t += DT
	for i in hs.size():
		print("ELIM %s %s %s" % [elim, ids[i], seen[i]])
	main.get_tree().quit(0)
