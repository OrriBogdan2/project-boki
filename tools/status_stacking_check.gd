extends RefCounted
## --status-stacking-check: two casters put the same status on one dummy and it follows the one rule per
## kind in content/rules/status_stacking.json (docs/COMBAT.md, Status stacking): slow, burn, stun and root
## keep the strongest and the longest (never added); Static, Shatter darts, Chill, Char and Ignite are one
## count on the body for both casters; Marks stay one count per caster.

var main: Node
var fails := 0
var n := 0
var ak = null

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("STACKCHECK %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _crowd_control()
	await _static()
	await _shatter_and_chill()
	await _char_and_ignite()
	await _marks()
	print("STACKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## [match, caster A, caster B (same team, same kit), the dummy].
func _pair(arch: String) -> Array:
	var r: Array = ak.setup(arch, 6.0)
	var m: Match = r[0]
	var a: Hunter = r[1]
	var at: Vector3 = r[4] + Vector3(0, 0, 2.0)
	var b: Hunter = m.make_hunter("B", a.team, Arch.weight(arch), "B", "idle", {}, at, {"arch": arch})
	b.set_arch(arch)
	b.unlock_all()
	ak.step(m, 0.1)
	return [m, a, b, r[2]]

func _hit(t: Hunter, by: Hunter, opts: Dictionary) -> void:
	t.hurt(1.0, by, opts)

func _crowd_control() -> void:
	var r := _pair("archer")
	var m: Match = r[0]
	var a: Hunter = r[1]
	var b: Hunter = r[2]
	var t: Hunter = r[3]
	_hit(t, a, {"slow": 2.0, "slow_k": 0.4})
	_hit(t, b, {"slow": 3.0, "slow_k": 0.2})
	ok("slow: the stronger slow wins, the longer time wins, they never add",
			is_equal_approx(t.slow_k, 0.4) and is_equal_approx(t.slow_t, 3.0), "k %.2f t %.2f" % [t.slow_k, t.slow_t])
	ok("slow: the speed is one slow's worth, not two multiplied", is_equal_approx(t.slow_mult(0.3), 0.6))
	ak.fresh(t)
	_hit(t, b, {"slow": 3.0, "slow_k": 0.2})
	_hit(t, a, {"slow": 2.0, "slow_k": 0.4})
	ok("slow: the order does not matter", is_equal_approx(t.slow_k, 0.4) and is_equal_approx(t.slow_t, 3.0))
	ak.fresh(t)
	_hit(t, a, {"stun": 1.0})
	_hit(t, b, {"stun": 0.6})
	ok("stun: a shorter stun from a second caster changes nothing", is_equal_approx(t.stun_t, 1.0), "%.2f" % t.stun_t)
	_hit(t, b, {"stun": 1.5})
	ok("stun: a longer one refreshes to its length, it does not extend (1.0 left + 1.5)",
			is_equal_approx(t.stun_t, 1.5), "%.2f" % t.stun_t)
	_hit(t, a, {"root": 1.0})
	_hit(t, b, {"root": 0.5})
	ok("root: the longer wins, never added", is_equal_approx(t.root_t, 1.0), "%.2f" % t.root_t)
	ak.fresh(t)
	_hit(t, a, {"burn": 5.0, "burn_for": 3.0})
	_hit(t, b, {"burn": 3.0, "burn_for": 5.0})
	ok("burn: the stronger burn and the longer time, credited to the stronger's caster",
			is_equal_approx(t.burn_dps, 5.0) and is_equal_approx(t.burn_t, 5.0) and t.burn_by == a,
			"dps %.1f t %.1f" % [t.burn_dps, t.burn_t])
	_hit(t, b, {"burn": 9.0, "burn_for": 1.0})
	ok("burn: a stronger one from the second caster takes over the credit",
			is_equal_approx(t.burn_dps, 9.0) and t.burn_by == b and is_equal_approx(t.burn_t, 5.0))
	ak.fresh(t)
	_hit(t, a, {"burn": 9.0, "burn_for": 0.1})
	ak.step(m, 0.3)
	_hit(t, b, {"burn": 2.0, "burn_for": 2.0})
	ok("burn: a burn that ran out leaves no strength behind", is_equal_approx(t.burn_dps, 2.0) and t.burn_by == b)
	m.queue_free()

func _static() -> void:
	var r := _pair("mage")
	var m: Match = r[0]
	var ka: MageKit = (r[1] as Hunter).ak
	var kb: MageKit = (r[2] as Hunter).ak
	var t: Hunter = r[3]
	ka.add_spark(t, 2)
	kb.add_spark(t, 1)
	ok("static: two Sparkles' stacks are one count on the dummy", ka.spark_n(t) == 3 and kb.spark_n(t) == 3,
			"%d / %d" % [ka.spark_n(t), kb.spark_n(t)])
	kb.add_spark(t, 1)
	ok("static: the second caster's hit makes it 4, Live for both", ka.live(t) and kb.live(t))
	ka.add_spark(t, 3)
	ok("static: past the top stays at 4", ka.spark_n(t) == 4)
	ak.step(m, float(ka.res_def()["dur"]) + 0.5)
	ok("static: it runs out once, on the body", ka.spark_n(t) == 0 and kb.spark_n(t) == 0)
	m.queue_free()

func _shatter_and_chill() -> void:
	var r := _pair("rimewright")
	var m: Match = r[0]
	var ka: RimewrightKit = (r[1] as Hunter).ak
	var kb: RimewrightKit = (r[2] as Hunter).ak
	var t: Hunter = r[3]
	ka.add_chill(t)
	kb.add_chill(t)
	ok("chill: two casters Chill one body once, not twice",
			ka.chilled(t) and Stacks.count(t, "chill") == 1.0)
	var need := int(ka.d["passive"].get("fan_hits", 8))
	for i in need / 2:
		ka.on_deal(t, 1.0, {"ab": "fan"})
	for i in need / 2 - 1:
		kb.on_deal(t, 1.0, {"ab": "fan"})
	ok("shatter: darts from two casters are one count", ka.fan_on(t) == need - 1 and kb.fan_on(t) == need - 1,
			"%d / %d" % [ka.fan_on(t), kb.fan_on(t)])
	kb.on_deal(t, 1.0, {"ab": "fan"})
	ak.step(m, 0.5)
	var bursts: int = ka.splinter_log + kb.splinter_log
	ok("shatter: the dart that fills it bursts it, whoever threw it", kb.fan_on(t) == 0 and bursts == 1,
			"bursts %d" % bursts)
	m.queue_free()

func _char_and_ignite() -> void:
	var r := _pair("ashwick")
	var m: Match = r[0]
	var ka: AshwickKit = (r[1] as Hunter).ak
	var kb: AshwickKit = (r[2] as Hunter).ak
	var t: Hunter = r[3]
	var top := float(ka.rd()["ignite_at"])
	ka.add_char(t, top * 0.6)
	ok("char: both Cinders read the same Char", is_equal_approx(kb.char_of(t), top * 0.6))
	var lit := kb.add_char(t, top * 0.6)
	ok("char: Char from two casters adds, the second sets it Ablaze", lit and ka.burning(t) == 1 and kb.burning(t) == 1)
	ok("char: Ablaze takes the Char with it", ka.char_of(t) == 0.0)
	ka.stoke(t)
	ok("ignite: the second caster's stoke makes it Flashover for both", ka.burning(t) == 2 and kb.burning(t) == 2)
	kb.stoke(t)
	ok("ignite: it stops at the top stage, it does not stack past it", kb.burning(t) == 2)
	m.queue_free()

func _marks() -> void:
	var r := _pair("thief")
	var m: Match = r[0]
	var ka: ThiefKit = (r[1] as Hunter).ak
	var kb: ThiefKit = (r[2] as Hunter).ak
	var t: Hunter = r[3]
	ka.add_mark(t, 2, true)
	kb.add_mark(t, 3, true)
	ok("mark: each Thief keeps her own count, two casters do not share it", ka.marks_on(t) == 2 and kb.marks_on(t) == 3,
			"%d / %d" % [ka.marks_on(t), kb.marks_on(t)])
	ka.add_mark(t, 1, true)
	ok("mark: a hit adds to the caster's own count only", ka.marks_on(t) == 3 and kb.marks_on(t) == 3)
	m.queue_free()
