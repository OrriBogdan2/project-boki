extends "res://tools/combo51_shots.gd"
## --parity-strip --hero=<id> --slot=lmb|rmb|e|x|dash --frames=a-b --shots-dir=<dir> [--hold=<s>] [--footage-dir=<dir>]
## PARITY FIRST: a Hunter's move in the Training Area (the Arena) at 5 fps for the move's length, against the
## matching footage frames, as one JPG sheet <dir>/<hero>_<slot>.jpg: ours on the top row, footage frames a..b
## below, the same count, each labelled with its time from the press. Frame numbers are those of
## briefs/hero-ref/<sheet>.md; the footage comes from
## `git checkout origin/ext/hero-ref-footage -- footage/<folder>` (--footage-dir: where footage/ is).
## --hold=<s>: how long the key stays down (default: all of an LMB, a tap for the rest).
## Needs a renderer (jobq --needs gpu).

const FPS := 5.0                 # the footage's frame rate
const COLS := 6                  # frames per row; a long move wraps into more row pairs
const TILE := Vector2i(320, 180) # px of each frame on the sheet
const VIEW_CROP := Vector2i(640, 360)    # px of our render round the hero, the footage's centre crop matches it
const TAP := 0.1                 # s a tapped key stays down
const LABEL_H := 18              # px of the time strip under each tile
const FOOTAGE := {"gunslinger": "venator_ghost", "juggernaut": "juggernaut", "archer": "pin", "mage": "vireo",
	"bulwark": "bjorn", "dolm": "breah", "thief": "dancer", "dredge": "dredge", "ashwick": "linwick",
	"tender": "mooshmoosh", "rimewright": "tamsin", "ostra": "ostra"}      # our id -> footage/<folder>

var slot := "lmb"
var first_frame := 1
var count := 1
var hold := -1.0
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
	for k in P.slot_lv:
		P.slot_lv[k] = 3
	await _reset(6.0)
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
			elif t > TAP * 2.0:
				P.inp["move"] = Vector2.ZERO
	_aim(T.pos)

## (one frame of ours: the centre of the view, hero in the middle)
func _take(_kind: String, _file: String, _caption: String, _focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	shots.append(_crop(img, P.position + Vector3(0, 0.9, 0), VIEW_CROP, 1.0))

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
