class_name RoostTrainer
extends RefCounted
## The Boki Roost's fight trainer: a short guided drill on how a Boki fights, using only the real systems.
## Walk to the sign on the roost and press interact. Steps, each ticked off by what the game itself reports:
##   1 Summon:  the Summon key bursts your Boki out of its wisp (KinSummon); a practice wild Boki drops in.
##   2 Order:   tap G for a Sic at the cursor, or hold G and pick Chase on the order wheel (KinCommand).
##   3 Knock out: your Boki fights and casts its own ability (KinTactics); get the wild one "dazed" (Kin.state).
##   4 Scan:    hold interact beside it (Capture). The Grounds are a training match, so Match._catch keeps no
##              capsule and no stat; Capture.complete tells the trainer through scanned().
## If the wild Boki wakes before the scan, the drill drops back to step 3. Types: the wild Boki's ground disc is
## its type colour (WildTypeCue); the game has no damage chart between types, so the drill does not teach one.
## The step line sits under the Grounds pedestal prompt (top centre), clear of the trial clock, hunter and corners.

const SIGN_OFF := Vector3(0, 0, 5.5)  # [m] from the roost's middle (the summon pad) to the sign
const WILD_OFF := Vector3(7.0, 0, 0)  # [m] from the roost's middle to where the practice wild Boki stands
const ACT_R := 2.5  # [m] how close you stand to start the drill
const WILD_LEVEL := 3  # the practice Boki's level: weak, it just has to be knocked out
const DONE_S := 6.0  # [s] the "well done" line stays
const LINE_Y := Grounds.PROMPT_Y + 32.0  # [px] the step line's top: just under the pedestal prompt
const COL := Color("ffe9b8")
const SIGN_TEXT := "BOKI TRAINER\nLearn how Boki fight: summon, order,\nknock out and scan a wild one.\n%s to start"
enum Step { IDLE = -1, SUMMON, ORDER, KNOCK, SCAN, DONE }

var a: Arena
var sign_at: Vector3
var wild_at: Vector3
var step := Step.IDLE
var wild: Kin = null
var line: Label = null
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
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 20)
	line.add_theme_color_override("font_color", COL)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	line.custom_minimum_size = Vector2(Grounds.PROMPT_W + 200.0, 0)
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	line.grow_horizontal = Control.GROW_DIRECTION_BOTH
	line.offset_top = LINE_Y
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.visible = false
	layer.add_child(line)


## Capture.complete, after every finished scan: the practice Boki's scan ends the drill.
static func scanned(m, h: Hunter, k: Kin) -> void:
	if m.arena == null or m.arena.grounds == null or h != m.player:
		return
	var tr: RoostTrainer = m.arena.grounds.roost_trainer
	if tr != null and tr.step == Step.SCAN and k == tr.wild:
		tr._finish()


func _ground(p: Vector3) -> Vector3:
	p.y = a.m.world.ground_at(p.x, p.z)
	return p


func tick(dt: float) -> void:
	var p: Hunter = a.m.player
	if step == Step.IDLE:
		if p.flat_dist(sign_at) < ACT_R and Input.is_action_just_pressed("interact") and not a.m.paused:
			start()
		return
	if step == Step.DONE:
		_done_t -= dt
		if _done_t <= 0.0:
			stop()
		return
	if p.downed or p.pos.y < Grounds.FALL_Y:
		stop()
		return
	_advance(p)
	_show(_line_for(p))


func start() -> void:
	step = Step.SUMMON
	a.m.fx.ring(sign_at, 1.2, COL, 0.3)


## Leave the drill (done, or you fell): the practice Boki goes away.
func stop() -> void:
	step = Step.IDLE
	_free_wild()
	line.visible = false
	_text = ""


func _finish() -> void:
	step = Step.DONE
	_done_t = DONE_S
	_free_wild()
	var p: Hunter = a.m.player
	a.m.fx.burst(p.pos + Vector3(0, 1.0, 0), COL, 18, 3.5, 0.5)
	_show("Well done: that is a Boki fight. Summon, order, knock out, scan.")


func _free_wild() -> void:
	if wild != null and is_instance_valid(wild) and not wild.dead:
		a.m.kins.erase(wild)
		wild.queue_free()
	wild = null


func _advance(p: Hunter) -> void:
	var k: Kin = p.kin
	if step == Step.SUMMON:
		if k != null and k.summon != null and k.summon.out():
			step = Step.ORDER
			_spawn_wild()
		return
	if wild == null or not is_instance_valid(wild) or wild.dead:
		_spawn_wild()  # (it fell off, or left: a fresh one, back to knocking out)
		step = mini(step, Step.KNOCK)
	if wild.state == "dazed":
		step = Step.SCAN  # (knocked out before an order: the order step is skipped, not failed)
	elif step == Step.SCAN:
		step = Step.KNOCK  # it woke up
	elif step == Step.ORDER and k != null and (k.cmd == "chase" or bool(k.fly.get("sic", false))):
		step = Step.KNOCK


func _spawn_wild() -> void:
	var sp := String(SummonStation.rules()["species"][0])
	var rec := Save.new_kin(sp)
	rec["level"] = WILD_LEVEL
	wild = a.m.spawn_wild(rec, wild_at)
	a.m.fx.ring(wild_at, 1.4, COL, 0.4)


func _line_for(p: Hunter) -> String:
	var k: Kin = p.kin
	var g := Settings.key_cap("throw")
	var n := "%d/4  " % (step + 1)
	if step in [Step.ORDER, Step.KNOCK] and (k == null or k.summon == null or not k.summon.out()):
		return n + "Your Boki went back in its wisp: press %s again" % Settings.key_cap("summon")
	match step:
		Step.SUMMON:
			if k == null or k.dead:
				return "1/4  Step on the summon pad (roost middle), press %s for a Boki" % Settings.key_cap("interact")
			return "1/4  Press %s: your Boki bursts out of its wisp for a short while" % Settings.key_cap("summon")
		Step.ORDER:
			return "2/4  Give an order: tap %s at the wild one, or hold %s and pick Chase" % [g, g]
		Step.KNOCK:
			return "3/4  Knock it out. Your Boki fights and casts its ability by itself"
		Step.SCAN:
			return "4/4  It is knocked out: hold %s beside it to scan it" % Settings.key_cap("interact")
	return ""


func _show(text: String) -> void:
	line.visible = true
	if text != _text:
		_text = text
		line.text = text
