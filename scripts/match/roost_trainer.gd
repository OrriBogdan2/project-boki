class_name RoostTrainer
extends RefCounted
## The Boki Roost's fight trainer: a short guided drill on how a Boki fights, using only the real systems.
## Walk to the sign on the roost and press interact. Steps, each ticked off by what the game itself reports:
##   1 Summon:  the Summon key bursts your Boki out of its wisp (KinSummon).
##   2 Knock out: a practice wild Boki is dropped on the roost. Your Boki fights on its own and casts its own
##     ability (KinTactics); G taps a Sic at the cursor, G held opens the order wheel. Get the wild one to the
##     "dazed" state (Kin.state).
##   3 Scan: hold interact beside it to capture it (Capture); the practice capsule is handed back afterwards.
## If the wild Boki wakes before the scan, the drill drops back to step 2. Types: the wild Boki's ground disc is
## its type colour (WildTypeCue); the game has no damage chart between types, so the drill does not teach one.
## The step line is a screen label under the Grounds prompt (top centre), clear of the hunter and the corners.

const SIGN_OFF := Vector3(0, 0, 5.5)  # m from the roost's middle (the summon pad) to the sign
const WILD_OFF := Vector3(7.0, 0, 0)  # m from the roost's middle to where the practice wild Boki stands
const ACT_R := 2.5  # m: how close you stand to start the drill
const WILD_LEVEL := 3  # the practice Boki's level: weak, it just has to be knocked out
const DONE_S := 6.0  # s the "well done" line stays
const COL := Color("ffe9b8")
const SIGN_TEXT := "BOKI TRAINER\nLearn how Boki fight: summon, cast,\nknock out and scan a wild one.\n%s to start"

var a: Arena
var sign_at: Vector3
var wild_at: Vector3
var step := -1  # -1 idle, 0 summon, 1 knock out, 2 scan, 3 done
var wild: Kin = null
var line: Label = null
var _caught0 := 0
var _done_t := 0.0
var _text := ""


func _init(arena: Arena, middle: Vector3, layer: CanvasLayer) -> void:
	a = arena
	sign_at = _ground(middle + SIGN_OFF)
	wild_at = _ground(middle + WILD_OFF)
	var lb := Grounds.label(SIGN_TEXT % Settings.key_cap("interact"), COL, 2.6)
	lb.position = sign_at + Vector3(0, 2.6, 0)
	a.m.add_child(lb)
	var pad := Models.jump_pad(COL)
	pad.position = sign_at
	a.m.add_child(pad)
	line = Label.new()
	line.position = Vector2(0, 190)
	line.size = Vector2(1280, 30)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 20)
	line.add_theme_color_override("font_color", COL)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	line.visible = false
	layer.add_child(line)


func _ground(p: Vector3) -> Vector3:
	p.y = a.m.world.ground_at(p.x, p.z)
	return p


func tick(dt: float) -> void:
	var p: Hunter = a.m.player
	if step < 0:
		if p.flat_dist(sign_at) < ACT_R and Input.is_action_just_pressed("interact") and not a.m.paused:
			_start()
		return
	if step == 3:
		_done_t -= dt
		if _done_t <= 0.0:
			stop()
		return
	if p.downed or p.pos.y < Grounds.FALL_Y:
		stop()
		return
	_advance(p)
	_show(_line_for(p))


func _start() -> void:
	var p: Hunter = a.m.player
	step = 0
	_caught0 = p.caught.size()
	a.m.fx.ring(sign_at, 1.2, COL, 0.3)


## Leave the drill (done, or you fell): the practice Boki goes away.
func stop() -> void:
	step = -1
	_free_wild()
	line.visible = false
	_text = ""


func _free_wild() -> void:
	if wild != null and is_instance_valid(wild) and not wild.dead:
		a.m.kins.erase(wild)
		wild.queue_free()
	wild = null


func _advance(p: Hunter) -> void:
	var k: Kin = p.kin
	if step == 0 and k != null and k.summon != null and k.summon.out():
		step = 1
		_spawn_wild()
	elif step >= 1:
		_follow_wild(p)


func _spawn_wild() -> void:
	var sp := String(SummonStation.rules()["species"][0])
	var rec := Save.new_kin(sp)
	rec["level"] = WILD_LEVEL
	wild = a.m.spawn_wild(rec, wild_at)
	a.m.fx.ring(wild_at, 1.4, COL, 0.4)


func _follow_wild(p: Hunter) -> void:
	if p.caught.size() > _caught0:
		p.caught.resize(_caught0)  # a practice capsule never takes a real carry-out slot
		step = 3
		_done_t = DONE_S
		a.m.fx.burst(p.pos + Vector3(0, 1.0, 0), COL, 18, 3.5, 0.5)
		_show("Well done: that is a Boki fight. Summon, cast, knock out, scan.")
	elif wild == null or not is_instance_valid(wild) or wild.dead:
		wild = null
		_spawn_wild()
		step = 1
	else:
		step = 2 if wild.state == "dazed" else 1


func _line_for(p: Hunter) -> String:
	var k: Kin = p.kin
	match step:
		0:
			if k == null or k.dead:
				return "1/3  Step on the summon pad (roost middle), press %s for a Boki" % Settings.key_cap("interact")
			return "1/3  Press %s: your Boki bursts out of its wisp for a short while" % Settings.key_cap("summon")
		1:
			var g := Settings.key_cap("throw")
			return "2/3  Knock out the wild Boki. Yours fights alone: %s sends it at the cursor, hold %s: orders" % [g, g]
		2:
			return "3/3  It is knocked out: hold %s beside it to scan and capture it" % Settings.key_cap("interact")
	return ""


func _show(text: String) -> void:
	line.visible = true
	if text != _text:
		_text = text
		line.text = text
