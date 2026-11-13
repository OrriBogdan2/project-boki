extends RefCounted
## --creator-view-check: making yourself (hatch.gd + CreatorView). Dragging turns the model; the wheel
## and the See your face button go from the whole body to a close-up of the face and back; Surprise me
## rolls a look from every row's range, the same one for the same seed, keeping the glider, and one Back
## puts the old look back (a manual change after it drops the Back). With --shots-dir=<dir> (a real
## renderer) it saves the whole body, the face and a surprise. Prints CVIEW ok/FAIL lines and
## "CVIEW DONE, failures: N". Never touches the real save.

const FACE_NEAR := 1.8        # m: the close-up camera is at most this far from the face
const SETTLE_S := 3.0        # s: long enough for the camera to ease to a new shot
const BODY_SLACK := 0.15      # m: back at the whole body, give or take the idle's glances

var bad := 0
var main: Node
var shots := ""

func ok(cond: bool, what: String) -> void:
	print("CVIEW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	await main.show_screen("hatch", {"create": true})
	await _frames(20)
	var hx = main.current
	ok(hx.stage == "create" and hx.preview != null, "the creator is open with your model (stage %s)" % hx.stage)
	_rolls()
	await _turn(hx)
	await _zoom(hx)
	await _surprise(hx)
	print("CVIEW DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Waits for the camera to ease to its new shot.
func _settle() -> void:
	await main.get_tree().create_timer(SETTLE_S).timeout

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _rolls() -> void:
	var v := CreatorView.new()
	var start := Unmasked.default_look()
	start["glider"] = "kite"
	var a := v.surprise(start, 77)
	ok(a == CreatorView.new().surprise(start, 77), "the same seed gives the same look")
	var seen := {}
	var in_range := true
	for s in 40:
		var lk := v.surprise(start, s)
		seen[str(lk)] = true
		for row in Unmasked.ROWS:
			in_range = in_range and int(lk[row[0]]) >= 0 and int(lk[row[0]]) < (row[2] as Array).size()
		in_range = in_range and lk["glider"] == "kite"
	ok(in_range, "40 rolls: every row inside its range, the glider kept")
	ok(seen.size() >= 30, "40 seeds give different people (%d different)" % seen.size())

func _turn(hx) -> void:
	var yaw: float = hx.preview.rotation.y
	_mouse(MOUSE_BUTTON_LEFT, true)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(100, 0)
	hx._unhandled_input(mm)
	_mouse(MOUSE_BUTTON_LEFT, false)
	var turned := 100 * CreatorView.TURN_PER_PX
	ok(absf(hx.preview.rotation.y - yaw - turned) < 0.001, "a 100 px drag turns the model")
	hx._unhandled_input(mm)
	ok(absf(hx.preview.rotation.y - yaw - turned) < 0.001, "moving without the button held doesn't")
	hx.preview.rotation.y = yaw      # facing the camera again for the shots
	await _frames(1)

func _zoom(hx) -> void:
	await _settle()
	await _shot("creator_body", 2)
	var body_dist := _face_dist(hx)
	for i in 4:
		_mouse(MOUSE_BUTTON_WHEEL_UP, true)
		_mouse(MOUSE_BUTTON_WHEEL_UP, false)
	await _settle()
	ok(hx.view.want == 1.0 and _face_dist(hx) < FACE_NEAR and hx.view.button.text == "See all of you",
		"four wheel notches up: the face, and the button offers the way back (%.2f m, was %.2f m)"
		% [_face_dist(hx), body_dist])
	ok(_face_on_screen(hx), "the face is in the frame, right of the card")
	await _shot("creator_face", 5)
	for i in 4:
		_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	await _settle()
	ok(hx.view.want == 0.0 and absf(_face_dist(hx) - body_dist) < BODY_SLACK, "wheel down goes back to the whole body")
	var zb := _button(hx.create_box, "See your face")
	ok(zb != null, "a See your face button")
	if zb == null:
		return
	zb.pressed.emit()
	await _settle()
	ok(zb.text == "See all of you" and _face_dist(hx) < FACE_NEAR, "it comes in to the face and offers the way back")
	zb.pressed.emit()
	await _settle()
	ok(zb.text == "See your face" and absf(_face_dist(hx) - body_dist) < BODY_SLACK,
		"and pressed again, the whole body")

func _surprise(hx) -> void:
	hx.look["glider"] = "kite"
	var before: Dictionary = hx.look.duplicate(true)
	ok(_button(hx.create_box, "Back") == null, "no Back before a surprise")
	var tries := 0
	while hx.look == before and tries < 5:
		_button(hx.create_box, "Surprise me").pressed.emit()
		await _frames(3)
		tries += 1
	ok(hx.look != before and hx.look["glider"] == "kite" and Unmasked.is_look(hx.look),
		"Surprise me makes a new person, a whole valid look, the glider kept")
	await _shot("creator_surprise", 20)
	var rolled: Dictionary = hx.look.duplicate(true)
	_button(hx.create_box, "Surprise me").pressed.emit()
	await _frames(3)
	var back := _button(hx.create_box, "Back")
	ok(back != null, "a Back button after it")
	if back:
		back.pressed.emit()
		await _frames(3)
	ok(hx.look == rolled and _button(hx.create_box, "Back") == null, "one Back puts the look before it back, then goes")
	_button(hx.create_box, "Surprise me").pressed.emit()
	await _frames(3)
	var row: Array = Unmasked.ROWS[0]
	hx._step_look(row[0], 1, (row[2] as Array).size())
	await _frames(3)
	ok(_button(hx.create_box, "Back") == null, "changing a row yourself after a surprise drops the Back")

func _mouse(idx: MouseButton, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = idx
	mb.pressed = pressed
	main.current._unhandled_input(mb)

func _face(hx) -> Vector3:
	var neck := hx.preview.find_child("HeadPivot", true, false) as Node3D
	return neck.global_position + Vector3(0, CreatorView.FACE_UP, 0)

func _face_dist(hx) -> float:
	return (hx.cam as Camera3D).global_position.distance_to(_face(hx))

func _face_on_screen(hx) -> bool:
	var cam := hx.cam as Camera3D
	var p := cam.unproject_position(_face(hx))
	var vs := main.get_viewport().get_visible_rect().size
	return not cam.is_position_behind(_face(hx)) and p.x > vs.x * 0.5 and p.x < vs.x and p.y > 0 and p.y < vs.y

func _button(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text == txt:
		return n
	for c in n.get_children():
		var f := _button(c, txt)
		if f:
			return f
	return null

func _shot(file: String, frames: int) -> void:
	await _frames(frames)
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, file])
	print("CVIEW shot %s" % file)
