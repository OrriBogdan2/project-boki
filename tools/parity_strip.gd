extends "res://tools/combo51_shots.gd"
## --parity-strip --hero=<id> --slot=lmb|rmb|e|x|dash --frames=a-b --shots-dir=<dir> [--hold=<s>] [--pillar=<m>]
##     [--footage-dir=<dir>]
## PARITY FIRST: a Hunter's move in the Training Area (the Arena) at 5 fps for the move's length, against the
## matching footage frames, as one JPG sheet <dir>/<hero>_<slot>.jpg: ours on the top row, footage frames a..b
## below, the same count, each labelled with its time from the press. Frame numbers are those of
## briefs/hero-ref/<sheet>.md; the footage comes from
## `git checkout origin/ext/hero-ref-footage -- footage/<folder>` (--footage-dir: where footage/ is).
## --hold=<s>: how long the key stays down (default: all of an LMB, a tap for the rest; a dash: how long she keeps
## moving). --pillar=<m>: a dark rock pillar that far ahead on her line, on a rock tile she can only walk
## through as a spirit (footage pin 0358-0366: Spirit Walk through a pillar), the dummy PAST_PILLAR beyond it.
## Needs a renderer (jobq --needs gpu).

const FPS := 5.0                 # the footage's frame rate
const COLS := 6                  # frames per row; a long move wraps into more row pairs
const TILE := Vector2i(320, 180) # px of each frame on the sheet
const VIEW_CROP := Vector2i(480, 270)    # px of our render round the hero and the dummy
const AHEAD := 2.5               # m toward the dummy the crop is centred, so the shots show
const TAP := 0.1                 # s a tapped key stays down
const LABEL_H := 24              # px of the time strip under each tile
const PILLAR_R := 0.6              # m: the pillar stands on one rock tile, about the footage pillar's width
const PILLAR_TALL := 3.0           # m the pillar stands
const PAST_PILLAR := 4.5           # m from the pillar's middle to the dummy, clear of where she stops
const FOOTAGE := {"gunslinger": "venator_ghost", "juggernaut": "juggernaut", "archer": "pin", "mage": "vireo",
	"bulwark": "bjorn", "dolm": "breah", "thief": "dancer", "dredge": "dredge", "ashwick": "linwick",
	"tender": "mooshmoosh", "rimewright": "tamsin", "ostra": "ostra"}      # our id -> footage/<folder>

var slot := "lmb"
var first_frame := 1
var count := 1
var hold := -1.0
var pillar := 0.0
var footage_dir := "res://"
var shots: Array = []

func run(main_node: Node) -> void:
	main = main_node
	var range_arg := ""
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
		if arg.begins_with("--hero="): who = arg.substr(7)
		if arg.begins_with("--slot="): slot = arg.substr(7)
		if arg.begins_with("--frames="): range_arg = arg.substr(9)
		if arg.begins_with("--hold="): hold = float(arg.substr(7))
		if arg.begins_with("--pillar="): pillar = float(arg.substr(9))
		if arg.begins_with("--footage-dir="): footage_dir = arg.substr(14)
	var ends := range_arg.split("-")
	if ends.size() != 2 or not FOOTAGE.has(who) or not ["lmb", "rmb", "e", "x", "dash"].has(slot):
		push_error("--parity-strip --hero=<id> --slot=lmb|rmb|e|x|dash --frames=a-b --shots-dir=<dir>")
		main.get_tree().quit(1)
		return
	first_frame = int(ends[0])
	count = int(ends[1]) - first_frame + 1
	hero_name = who
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	P.lvl = 6
	if m.hud:
		m.hud.guide_hidden = true      # (the kit card would sit over the hero)
	for k in P.slot_lv:
		P.slot_lv[k] = 3
	if pillar > 0.0:
		_raise_pillar(home + Vector3(pillar, 0, 0))
	Input.warp_mouse(Vector2.ONE)      # (the pointer off the field: no hover card over the dummy in the frames)
	await _reset(pillar + PAST_PILLAR if pillar > 0.0 else 6.0)
	await _go(count / FPS, _drive, _marks(), 1.0)
	var out := dir.path_join("%s_%s.jpg" % [who, slot])
	await _sheet(out)
	print("PARITYSTRIP %d frames in %s" % [count, out])
	main.get_tree().quit(0)

func _marks() -> Array:
	var out: Array = []
	for i in count:
		out.append([i / FPS, "ours", "", ""])
	return out

## The key for the slot, held `hold` s (an LMB: the whole move) from the first step.
func _drive(t: float) -> void:
	Sfx.listener = P.pos           # (the match's own step is off here: the looks' detail share follows her)
	var held := hold
	if held < 0.0:
		held = count / FPS if slot == "lmb" else TAP
	var down := t < held
	match slot:
		"lmb":
			P.inp["fire"] = down
		"rmb":
			P.inp["sec"] = _at(t, TAP)
			P.inp["sec_hold"] = down
		"e":
			P.inp["sig"] = _at(t, TAP)
		"x":
			if _at(t, TAP):
				P.ak.cd["x"] = 0.0
				P.ak.cast_ult()
		"dash":
			if _at(t, TAP):
				P.inp["move"] = Vector2(1, 0)
				P.do_dash()
			elif t > maxf(held, TAP * 2.0):
				P.inp["move"] = Vector2.ZERO
	_aim(T.pos)

## The --pillar: a rock tile at `at` (a plain walk stops at it) under a dark stone pillar.
func _raise_pillar(at: Vector3) -> void:
	var W: World = m.world
	var wk: PackedByteArray = W.kind
	wk[W.idx(int(at.x), int(at.z))] = World.T_BLOCK
	W.kind = wk
	var stone := CylinderMesh.new()
	stone.top_radius = PILLAR_R
	stone.bottom_radius = PILLAR_R
	stone.height = PILLAR_TALL
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.12)
	var mi := MeshInstance3D.new()
	mi.mesh = stone
	mi.material_override = dark
	m.add_child(mi)
	mi.global_position = Vector3(int(at.x) + 0.5, at.y + PILLAR_TALL * 0.5, int(at.z) + 0.5)

## (one frame of ours: the centre of the view, hero in the middle)
func _take(_kind: String, _file: String, _caption: String, _focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var toward := Vector3(T.position.x - P.position.x, 0, T.position.z - P.position.z).normalized()
	var at := P.position + toward * AHEAD + Vector3(0, 0.9, 0)
	shots.append(_crop(img, at, VIEW_CROP, 1.0))

func _footage(n: int) -> Image:
	var path := footage_dir.path_join("footage/%s/frames/%04d.jpg" % [FOOTAGE[who], n])
	var img := Image.load_from_file(path)
	if img == null:
		push_error("parity-strip: no footage frame " + path)
		return Image.create(VIEW_CROP.x, VIEW_CROP.y, false, Image.FORMAT_RGB8)
	var w := int(img.get_width() * 0.5)
	var h := int(w * VIEW_CROP.y / float(VIEW_CROP.x))
	return img.get_region(Rect2i((img.get_width() - w) / 2, (img.get_height() - h) / 2, w, h))

## The sheet: row pairs of COLS tiles (ours, then the footage), a time label under each, saved as a JPG.
func _sheet(path: String) -> void:
	var rows := ceili(count / float(COLS))
	var pair_h := 2 * (TILE.y + LABEL_H)
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * TILE.x, rows * pair_h + LABEL_H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07)
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var head := Label.new()
	head.text = "%s %s: ours (top), footage %s %04d-%04d (below), %d fps" % [
			who, slot, FOOTAGE[who], first_frame, first_frame + count - 1, int(FPS)]
	vp.add_child(head)
	for i in count:
		var at := Vector2((i % COLS) * TILE.x, LABEL_H + (i / COLS) * pair_h)
		_tile(vp, shots[i], at, "ours  +%.1fs" % (i / FPS))
		var label := "src %04d  +%.1fs" % [first_frame + i, i / FPS]
		_tile(vp, _footage(first_frame + i), at + Vector2(0, TILE.y + LABEL_H), label)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	vp.get_texture().get_image().save_jpg(path, 0.9)
	vp.queue_free()

func _tile(parent: Node, img: Image, at: Vector2, text: String) -> void:
	img.resize(TILE.x - 2, TILE.y, Image.INTERPOLATE_BILINEAR)
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(img)
	tex.position = at
	parent.add_child(tex)
	var lab := Label.new()
	lab.text = text
	lab.position = at + Vector2(2, TILE.y)
	parent.add_child(lab)
