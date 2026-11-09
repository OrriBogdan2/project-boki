extends RefCounted
## --focus-loss-check: the window loses focus (NOTIFICATION_APPLICATION_FOCUS_OUT, sent to the whole tree as the
## engine does) while a button is held, for all 12 Hunters. Each of LMB, RMB, Shift, W, Ctrl and a held aimed E is
## held, then: every action reads up, the Hunter's inputs and holds are clear (no bow draw, charge or held RMB), the
## cursor is shown, and nothing goes off afterwards: no shot, swing or ability (no perfect release). A normal release of
## Lace's draw does shoot (the control), a hold made while a menu is up does not carry out of it, and the
## hold-to-skip and hold-to-unlock buttons let go. Never touches the save.

const HOLDS := ["fire", "secondary", "dash", "up", "crouch", "signature"]      # LMB, RMB, Shift, W, Ctrl, E
const AFTER := 60       # steps watched after the loss

var bad := 0
var hunter: Hunter
var cast_n := 0
var fire_n := 0         # shots, arrows and swings started since the last reset
var cast_log := []
var cursor_was := Input.MOUSE_MODE_VISIBLE

func ok(cond: bool, what: String) -> void:
	print("FOCUS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(func(caster: Node, a: String, s: String):
		if caster == hunter:
			cast_n += 1
			cast_log.append("%s/%s" % [a, s]))
	for hero in _heroes():
		var m := Match.new()
		main.add_child(m)
		m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
				"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero)})
		m.set_process(false)
		for mob in m.mobs:
			mob.queue_free()
		m.mobs.clear()
		hunter = m.player
		hunter.set_arch(hero)
		hunter.unlock_all()
		for other in m.hunters:
			if other != hunter:
				other.ctrl = "idle"
				other.teleport(hunter.pos + Vector3(60, 0, 60))
		await _paused_hold(main, m, hero)
		for act in HOLDS:
			await _hold_then_lose(main, m, hero, act)
		if hero == "archer":
			await _normal_release_shoots(m)
		m.queue_free()
		await main.get_tree().process_frame
	_hold_buttons(main)
	print("FOCUS DONE, failures: %d" % bad)
	main.get_tree().quit()

## Every Hunter, or the ones named in --focus-loss-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus-loss-check=") and arg.length() > 19:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## One engine frame per step, so Input.is_action_just_pressed sees a press once, as in the game.
func _steps(m: Match, n: int) -> void:
	for i in n:
		var cd := hunter.fire_cd
		var swing := hunter.swing_t
		m._gather_input()
		m.step(Match.DT)
		if hunter.fire_cd > cd + 0.0001 or (hunter.swing_t > 0.0 and swing <= 0.0):
			fire_n += 1
		await m.get_tree().process_frame

func _down_actions() -> Array:
	return InputMap.get_actions().filter(func(a): return Input.is_action_pressed(a))

func _lose_focus(main: Node) -> void:
	main.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

func _fresh(m: Match) -> void:
	hunter.set_arch(hunter.arch)
	hunter.hp = hunter.max_hp
	hunter.stun_t = 0.0
	hunter.ammo = 99
	m.aim_hold = ""
	await _steps(m, 40)

func _hold_then_lose(main: Node, m: Match, hero: String, act: String) -> void:
	var what := "%s holding %s" % [hero, act]
	await _fresh(m)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	cursor_was = Input.mouse_mode
	Input.action_press(act)
	await _steps(m, 30)
	ok(Input.is_action_pressed(act), "%s: held before the loss" % what)
	_lose_focus(main)
	ok(_down_actions().is_empty(), "%s: every action reads up (%s)" % [what, str(_down_actions())])
	ok(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s: cursor shown" % what)
	fire_n = 0
	cast_n = 0
	cast_log.clear()
	await _steps(m, AFTER)
	var held_left: Array = FocusLoss.HELD.filter(func(k): return bool(hunter.inp.get(k, false)))
	ok(held_left.is_empty() and hunter.inp["move"] == Vector2.ZERO, "%s: inputs clear (%s)" % [what, str(held_left)])
	ok(hunter.draw_t < 0.0 and hunter.mel_hold <= 0.0 and not hunter.ak.rmb_down and m.aim_hold == "",
			"%s: no draw, charge, held RMB or aim left" % what)
	ok(fire_n == 0 and cast_n == 0, "%s: nothing fires afterwards (shots %d, casts %s)" % [what, fire_n, str(cast_log)])
	main.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	ok(Input.mouse_mode == cursor_was, "%s: cursor back as it was on return" % what)

## A hold made while a menu is up: the loss lets go of it, and closing the menu starts nothing.
func _paused_hold(main: Node, m: Match, hero: String) -> void:
	await _fresh(m)
	Input.action_press("fire")
	m.paused = true
	await _steps(m, 20)
	_lose_focus(main)
	m.paused = false
	fire_n = 0
	cast_n = 0
	cast_log.clear()
	await _steps(m, AFTER)
	ok(_down_actions().is_empty() and fire_n == 0 and cast_n == 0,
			"%s: a hold made under a menu does not fire when it closes (casts %s)" % [hero, str(cast_log)])

## The control: Lace's bow draw let go normally looses an arrow, so the loss above really is a cancel.
func _normal_release_shoots(m: Match) -> void:
	await _fresh(m)
	Input.action_press("fire")
	await _steps(m, 40)
	fire_n = 0
	Input.action_release("fire")
	await _steps(m, 10)
	ok(fire_n > 0, "archer: a normal release of the draw looses an arrow (control)")

func _hold_buttons(main: Node) -> void:
	var skip := HoldSkip.new()
	main.add_child(skip)
	skip.mouse_held = true
	_lose_focus(main)
	ok(not skip.mouse_held, "hold-to-skip lets go on the loss")
	skip.queue_free()
	var unlock := HoldUnlock.make("archer", null)
	main.add_child(unlock)
	unlock.press()
	_lose_focus(main)
	ok(not unlock.holding, "hold-to-unlock lets go on the loss")
	unlock.queue_free()
