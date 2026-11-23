extends "res://tools/vv_shots.gd"
## --vex-cast-closeup --shots-dir=<dir>: close-up film frames of Vex's Coin Blast (RMB) and Palm Lance (E) in a live
## Arena match (needs a renderer), from the front, from 3/4 on her free-hand side (wide: the coin's strike is in
## shot) and close on the free hand, the HUD off. Every drawn
## frame goes to <dir>/<move>_<view>/NNNN.jpg at 60 a second (jobq's GPU worker returns the out dir, not a movie):
##   ffmpeg -framerate 60 -i <dir>/rmb_front/%04d.jpg -pix_fmt yuv420p rmb_front.mp4

## view -> [camera, look-at, lens in degrees], in metres from her feet; she aims +X, her free hand on -Z. The
## front camera stands off the aim line on her gun side (the coin and the beam pass it, not through it); the 3/4
## one is on her free-hand side and wide enough to hold her and the coin's strike; "hand" is the same side, close.
const VIEWS := {
	"front": [Vector3(5.0, 1.7, 1.5), Vector3(0.5, 1.15, -0.2), 38.0],
	"side": [Vector3(3.4, 1.8, -4.6), Vector3(1.8, 1.0, 0.0), 46.0],
	"hand": [Vector3(2.5, 1.6, -2.7), Vector3(0.7, 1.2, 0.0), 42.0]
}
const FILM := {"rmb": 1.4, "e": 1.9}  # s filmed per move
const LEAD := 0.35  # s at rest before the press
## move -> the dummy's [distance, sideways] in m: the coin strikes it in the 3/4 view, the beam's is out of shot.
const DUMMY := {"rmb": [4.5, 0.0], "e": [30.0, 12.0]}

var eye: Camera3D
var into := ""
var frame := 0  # of this take
var total := 0
var move := ""
var pressed := false


func run(main_node: Node) -> void:
	main = main_node
	who = "gunslinger"
	hero_name = "venator"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	await _setup()
	for layer in main.find_children("*", "CanvasLayer", true, false):
		layer.visible = false  # the HUD, the drill banner and the Arena bar sit over the frame
	eye = Camera3D.new()
	m.add_child(eye)
	for mv in FILM:
		for view in VIEWS:
			await _film(String(mv), String(view))
	print("VEXCLOSE %d frames in %s" % [total, dir])
	main.get_tree().quit(0)


func _film(mv: String, view: String) -> void:
	var dummy: Array = DUMMY[mv]
	await _reset(float(dummy[0]), float(dummy[1]))
	_aim(home + Vector3(8.0, 0, 0))
	await _go(0.4)
	move = mv
	frame = 0
	pressed = false
	into = dir.path_join("%s_%s" % [mv, view])
	DirAccess.make_dir_recursive_absolute(into)
	eye.look_at_from_position(home + (VIEWS[view][0] as Vector3), home + (VIEWS[view][1] as Vector3))
	eye.fov = float(VIEWS[view][2])
	eye.make_current()
	Sfx.listener = P.pos  # (the match camera's follow is off here, and HeroVfx draws nothing far from the listener)
	await _go(float(FILM[mv]), _shoot)
	await _go(1.2)  # (the coin's cone or the beam done before the next take)


## Before each step: the last drawn frame is saved, and the move is pressed once the lead is over.
func _shoot(t: float) -> void:
	if t > 0.0:
		main.get_viewport().get_texture().get_image().save_jpg(into.path_join("%04d.jpg" % frame), 0.9)
		frame += 1
		total += 1
	if t >= LEAD and not pressed:
		pressed = true
		if move == "rmb":
			P.ak.press_rmb()
		else:
			P.ak.use_e()
