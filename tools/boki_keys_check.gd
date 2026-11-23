extends RefCounted
## --boki-keys-check: the quick Boki command keys (KinKeys) do exactly what the G wheel and G tap do.
##   1. default: five actions listed in Controls, all unbound, G alone on "throw", nothing on the kit card
##   2. bound: each key shows in Controls with its cap and on the kit card
##   3. each order key through Match._gather_input ends in the same Boki state as the wheel pick
##   4. the summon key sends the Boki out and calls it back, like a G tap
##   5. never eaten: two keys in one frame both run, a key and a wheel pick in one frame both run, a paused game
##      ignores a press, and the G wheel itself still works
## Run with a temporary XDG_DATA_HOME: it rebinds keys (Settings writes its config file).

var bad := 0
var m: Match
var main: Node
var mob: Mob
const KEYS := {
	"kin_summon": KEY_KP_0, "kin_chase": KEY_KP_1, "kin_guard": KEY_KP_2,
	"kin_return": KEY_KP_3, "kin_follow": KEY_KP_4,
}

func ok(cond: bool, what: String) -> void:
	print("BOKIKEYS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	_default()
	_fresh()
	_bound()
	_orders()
	_summon()
	_not_eaten()
	print("BOKIKEYS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fresh() -> void:
	m = Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"demo_kin": "cindle", "weapon": "rifle", "cls": "medium",
	})
	m.set_process(false)
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(60.0, 0, 40.0))
	_run(0.8)
	_foe()

## One live foe 6 m off, for Chase (the Boki may have beaten the last one).
func _foe() -> void:
	if mob == null or not is_instance_valid(mob) or mob.dead:
		mob = m.spawn_mob("skitter", m.player.pos)
	mob.hp = mob.max_hp
	mob.teleport(m.player.pos + Vector3(6.0, 0, 0))
	m.player.inp["aim"] = mob.pos + Vector3(0, 0.9, 0)

func _clear_mobs() -> void:
	for mb in m.mobs.duplicate():
		if mb != mob:
			m.mobs.erase(mb)
			mb.queue_free()

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		_clear_mobs()
		m.step(Match.DT)
		t += Match.DT

func _key_event(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _press(actions: Array) -> void:
	for a in actions: Input.action_press(a)
	m._gather_input()
	for a in actions: Input.action_release(a)

## What an order leaves on the Boki: its order and its chase target.
func _snap() -> Array:
	var k: Kin = m.player.kin
	return [k.cmd, k.chase_target]

func _reset_order() -> void:
	KinCommand.order(m.player, "return")
	_run(1.5)
	KinCommand.order(m.player, "follow")
	_run(1.2)
	_foe()

func _default() -> void:
	var ids := KinKeys.ids()
	var listed: bool = ids.all(func(a): return Settings.ACTIONS.any(func(x): return x[0] == a))
	ok(ids.size() == 5 and listed, "five quick keys are in the Controls list")
	ok(ids.all(func(a): return InputMap.has_action(a) and Settings.slots(a) == ["", ""]), "...and all start unbound")
	var bare: bool = KinKeys.card_lines(Color.WHITE).is_empty()
	ok(Settings.key_cap("throw") == "G" and bare, "a new player sees only G (nothing on the kit card)")

func _bound() -> void:
	for a in KEYS:
		Settings.rebind(a, _key_event(KEYS[a]), 0)
	var lines := KinKeys.card_lines(Color.WHITE)
	var caps: Array = lines.map(func(l): return l[0])
	var chase_cap := Settings.key_caps("kin_chase")
	ok(lines.size() == 5 and caps.has(chase_cap) and chase_cap != "?", "bound keys on the kit card: %s" % str(caps))
	var clash: bool = KEYS.keys().any(func(a): return not Settings.conflicts(_key_event(KEYS[a]), a).is_empty())
	ok(not clash, "no quick key clashes with another action")

func _orders() -> void:
	var P := m.player
	var k: Kin = P.kin
	for action in KinKeys.ORDERS:
		var id: String = KinKeys.ORDERS[action]
		_reset_order()
		_press([action])
		_run(0.1)
		var by_key := _snap()
		_reset_order()
		KinWheel.open(P, Vector2(300, 300))
		KinWheel.update(P, Vector2(300, 300) + (KinWheel.SEGMENTS[_segment(id)]["dir"] as Vector2) * 80.0, 0.05)
		P.inp["wheel_pick"] = KinWheel.close(P)
		_run(0.1)
		ok(k.cmd == id and by_key == _snap(), "%s leaves the Boki as the wheel's %s does (%s)" % [action, id, k.cmd])

func _segment(id: String) -> int:
	for i in KinWheel.SEGMENTS.size():
		if KinWheel.SEGMENTS[i]["id"] == id: return i
	return -1

func _summon() -> void:
	var P := m.player
	var k: Kin = P.kin
	_reset_order()
	_press(["kin_summon"])
	_run(0.15)
	var sent: bool = bool(k.fly.get("sic", false)) or k.state == "flying"
	KinCommand.call_back(P)
	_run(1.5)
	_reset_order()
	KinCommand.tap(P)
	_run(0.15)
	var tapped: bool = bool(k.fly.get("sic", false)) or k.state == "flying"
	ok(sent and tapped, "the summon key sends the Boki out like a G tap (key %s, tap %s)" % [sent, tapped])
	_run(0.5)
	_press(["kin_summon"])
	_run(0.3)
	var home: bool = k.state in ["returning", "shoulder"] or not KinCommand.is_away(P, k)
	ok(home, "...and the same key calls it back (state %s)" % k.state)

func _not_eaten() -> void:
	var P := m.player
	var k: Kin = P.kin
	_reset_order()
	_press(["kin_guard", "kin_follow"])
	_run(0.1)
	ok(k.cmd == "follow", "two keys in one frame both run, in order (ends on %s)" % k.cmd)
	_reset_order()
	P.inp["wheel_pick"] = "guard"
	_press(["kin_follow"])
	_run(0.1)
	ok(k.cmd == "follow", "a quick key beside a wheel pick in one frame: both run (ends on %s)" % k.cmd)
	_reset_order()
	m.paused = true
	_press(["kin_guard"])
	m.paused = false
	_run(0.1)
	ok(k.cmd == "follow" and not P.inp.has("kin_keys"), "a press while paused is ignored")
	KinWheel.open(P, Vector2(300, 300))
	KinWheel.update(P, Vector2(300, 220), 0.05)
	P.inp["wheel_pick"] = KinWheel.close(P)
	_run(0.1)
	ok(k.cmd == "chase", "the G wheel still picks (%s)" % k.cmd)
