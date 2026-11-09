extends RefCounted
## --dash-flow-check: for every hero, every dash -> ability pair does what its row in content/dash_flow says
## (DashFlow): pressed early in the dash and on its last step, on the ground and in the air, the ability goes off
## mid-dash ("fire"), at the dash's end ("buffer"), or ends the dash and goes off at once ("cancel"), and the press
## is never lost. A dash the file lists in kit_owns must stay out of DashFlow's sight, and every other one in it.
## Item 51 (docs/decisions/0015-combo-flow.md): every slot against a ground dash, an air dash and a jump, cast
## mid-jump (jump rows), the move pressed in its recovery (into_dash / into_jump rows: acts within 0.1 s unless
## the row is an exception), and a hold carried through the move and let go there (hold rows). Every exception
## row needs a reason and a source; the list per hero prints at the end (the hero agents' worklist).
## It walks DashFlow.SLOTS for every hero, so rows added later are covered. --dash-flow-check=<id>,<id> runs only
## those heroes. Never touches the save.

const QUIET_MAX := 900          # steps: the last trial's ability (an ult, a zone) winds down first
const DASH_WAIT := 40           # steps: a dash with a wind-up shows up within this
const WATCH := 120              # steps after the press that we watch for the ability
const GLOVE := "barrier"        # Q: an active glove that stays where it's cast

## The source's dash -> LMB / X rows (docs/heroes/dash_interactions.md): [hero, dash, slot, mode]. Silent source:
## the press goes mid-dash; Zedran and Bjorn dash AS the attack (no slash or swing inside it:
## buffer), and their ult plants them, as Cinder's flight takes over (cancel).
const SOURCE_ROWS := [
	["archer", "ground", "lmb", "fire"], ["archer", "air", "lmb", "fire"],
	["mage", "ground", "lmb", "fire"], ["mage", "air", "lmb", "fire"],
	["ashwick", "ground", "lmb", "fire"], ["ashwick", "air", "lmb", "fire"],
	["dolm", "air", "lmb", "fire"],
	["juggernaut", "ground", "lmb", "buffer"], ["juggernaut", "air", "lmb", "buffer"],
	["bulwark", "ground", "lmb", "buffer"], ["bulwark", "air", "lmb", "buffer"],
	["juggernaut", "ground", "x", "cancel"], ["bulwark", "ground", "x", "cancel"], ["ashwick", "ground", "x", "cancel"],
]

var bad := 0
var skipped := 0
var cast_n := {}                # CombatBus slot name -> casts by the hunter under test
var hunter: Hunter
var wait_s := 0.0               # how long after the dash's end a buffered press went off

func ok(cond: bool, what: String) -> void:
	print("DASHFLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for r in SOURCE_ROWS:
		var row := DashFlow.row_of(r[0], r[2], r[1] == "air")
		ok(String(row["mode"]) == r[3], "%s %s dash -> %s is %s in the source" % [r[0], r[1], r[2], r[3]])
	for hero in _heroes():
		await check_hero(main, hero)
	_print_exceptions()
	print("DASHFLOW DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

## Every row of one hero (a hero's own combo check runs this for item 51); returns the failures so far.
func check_hero(main: Node, hero: String) -> int:
	return await _hero(main, hero, true)

## One hero's combo trials (item 51) run from inside its own combo check: every slot cast mid-jump, the move
## out of its recovery, and its holds carried through each move. Returns the failures (its DASHFLOW lines say
## which); the hero check asserts none.
func combos_of(main: Node, hero: String) -> int:
	return await _hero(main, hero, false)

## One hero's trials: the dash rows (`rows`) and the item 51 combos, per slot.
func _hero(main: Node, hero: String, rows: bool) -> int:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	for slot in DashFlow.SLOTS:
		var m := _match(main, hero)
		if rows:
			_slot(m, hero, slot)
		_combos(m, hero, slot)
		m.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(_on_used)
	return bad

## Every hero, or the ones named in --dash-flow-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dash-flow-check=") and arg.length() > 18:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

func _on_used(caster: Node, _ability: String, slot: String) -> void:
	if caster == hunter:
		cast_n[slot] = int(cast_n.get(slot, 0)) + 1

func _slot(m: Match, hero: String, slot: String) -> void:
	for in_air in [false, true]:
		if not _goes_idle(m, slot, in_air):
			skipped += 1
			print("DASHFLOW skip %s %s %s: it doesn't go off without a dash here either" % [
					hero, "air" if in_air else "ground", slot])
			continue
		var want := String(DashFlow.row_of(hero, slot, in_air)["mode"])
		var owned: bool = ("air" if in_air else "ground") in DashFlow.file_of(hero).get("kit_owns", [])
		for late in [false, true]:
			var what := "%s %s dash -> %s, pressed %s" % [hero, "air" if in_air else "ground", slot,
					"on its last step" if late else "early"]
			var got := _trial(m, slot, in_air, late)
			if owned or got == "n/a":
				ok(owned == (got == "n/a"), "%s: %s, kit_owns %s" % [what, got, "lists it" if owned else "doesn't"])
				continue
			# on the dash's last step a cancel can't be told from a fire: the dash ends there either way; nor can a
			# fire from a press that goes off on the very next step (a tap that fires on its release, like Tarek's)
			var next_step: bool = got == "buffer" and wait_s < Match.DT * 0.5
			var at_end_same: bool = late and (got in ["fire", "cancel"] or next_step) and want in ["fire", "cancel"]
			var waited := " %.2fs after the dash" % wait_s if got == "buffer" else ""
			ok(got == want or at_end_same, "%s: %s%s (row: %s)" % [what, got, waited, want])

## A fresh training match as `hero` on a flat patch, every slot open, a glove on Q, level 10.
func _match(main: Node, hero: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(hero), "arch": hero, "weapon": Arch.signature(hero),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	hunter = m.player
	var world: World = m.world
	var cx := int(floor(hunter.pos.x))
	var cz := int(floor(hunter.pos.z))
	var home_i: int = world.idx(cx, cz)
	var level: int = int(world.level[home_i]) if world.kind[home_i] != World.T_VOID else 0
	for dz in range(-24, 25):
		for dx in range(-24, 25):
			if not world.inb(cx + dx, cz + dz):
				continue
			var i: int = world.idx(cx + dx, cz + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = level
			world.island[i] = world.island[home_i]
			world.walls.erase(i)
			world.props.erase(i)
			world.stairs.erase(i)
	hunter.teleport(Vector3(cx + 0.5, level * World.LEVEL, cz + 0.5))
	hunter.set_arch(hero)
	hunter.unlock_all()
	hunter.lvl = 10
	hunter.gear[0] = {"id": GLOVE, "rar": 1}
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	set_meta("home", hunter.pos)
	_steps(m, 20)
	return m

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(Match.DT)

## Waits out the last trial (its dash, E, R, ult, held RMB), clears what it left standing (rocks, barriers), then
## puts the hunter back home, everything ready.
func _ready_up(m: Match) -> void:
	var k := hunter.ak
	for i in QUIET_MAX:
		var busy := k.e_t > 0.0 or k.r_t > 0.0 or not k.fuse.is_empty() or k.rmb_down or k.ult_running()
		if not busy and hunter.roll_t <= 0.0 and k.dash_left() <= 0.0 and hunter.grounded and i > 30:
			break
		m.step(Match.DT)
	if k.e_t > 0.0:
		# an E that waits for its recast (Motley's seed) would turn the next E press into that recast: a new kit
		hunter.set_arch(hunter.arch)
	for wall in m.verbs.walls.duplicate():
		m.verbs._break_wall(wall)          # (the last trial's rocks and barriers would block this one's)
	hunter.teleport(get_meta("home"))
	hunter.vel = Vector3.ZERO
	hunter.hp = hunter.max_hp
	hunter.stun_t = 0.0
	for key in k.cd:
		k.cd[key] = 0.0
	k.ch_rmb = float(k.rmb_charges())
	hunter.gear_cd[0] = 0.0
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.fire_cd = 0.0
	hunter.reload_t = 0.0
	hunter.ammo = maxi(hunter.ammo, int(hunter.wpn.get("mag", 0)))
	hunter.inp["move"] = Vector2.ZERO
	hunter.inp["fire"] = false
	hunter.inp["aim"] = hunter.pos + Vector3(0, 0.9, -6)
	_steps(m, 2)

## Control: the slot goes off when pressed without a dash, on the ground or up in the air (some need ground in
## reach or a target the trial doesn't set up).
func _goes_idle(m: Match, slot: String, in_air: bool) -> bool:
	_ready_up(m)
	if in_air:
		_lift()
	var before := _snap()
	_press(slot)
	for i in 30:
		m.step(Match.DT)
		hunter.inp["fire"] = false
		if _went_off(before, slot):
			return true
	return false

## One press during one dash: "fire" (went off mid-dash), "cancel" (went off at once and the dash stopped),
## "buffer" (held, then went off once the dash was over: a kit's own recovery after its dash can delay it), "lost",
## or "n/a" (no dash DashFlow sees).
func _trial(m: Match, slot: String, in_air: bool, late: bool) -> String:
	_ready_up(m)
	if in_air:
		_lift()
	hunter.inp["move"] = Vector2(0, -1)
	hunter.inp["dash"] = true
	var n := 0
	while not hunter.ak.in_dash() and n < DASH_WAIT:
		m.step(Match.DT)
		n += 1
	if not hunter.ak.in_dash():
		return "n/a"
	while late and hunter.ak.dash_left() > Match.DT * 1.5 and n < 300:
		m.step(Match.DT)
		n += 1
	var dash_left := hunter.ak.dash_left()
	var before := _snap()
	_press(slot)
	m.step(Match.DT)
	hunter.inp["fire"] = false
	if _went_off(before, slot):
		var stopped := not hunter.ak.in_dash() and dash_left > Match.DT * 2.5
		return "cancel" if stopped else "fire"
	var ended := -1
	for i in WATCH:
		var dashing := hunter.ak.in_dash()
		if not dashing and ended < 0:
			ended = i
		m.step(Match.DT)
		hunter.inp["fire"] = false      # DashFlow's replayed LMB is a tap: let go, or a hold-to-charge weapon charges
		if _went_off(before, slot):
			wait_s = float(i - ended) * Match.DT
			return "fire" if dashing else "buffer"
	return "lost"

func _lift() -> void:
	hunter.pos += Vector3(0, 7, 0)
	hunter.grounded = false

func _press(slot: String) -> void:
	match slot:
		"lmb":
			hunter.inp["fire"] = true      # a tap: one step down
		"x":
			HunterKeys.ult_pressed(hunter)
		_:
			hunter.inp[DashFlow.KEY_OF[slot]] = true

## What a press leaves behind, to tell whether it went off.
func _snap() -> Dictionary:
	var k := hunter.ak
	return {
		"cd": k.cd.duplicate(), "ch": k.ch_rmb, "rmb_down": k.rmb_down, "e_t": k.e_t, "used": hunter.used.duplicate(),
		"gear": float(hunter.gear_cd[0]), "fire_cd": hunter.fire_cd, "swing": hunter.swing_t, "draw": hunter.draw_t,
		"mel": hunter.mel_hold, "ammo": hunter.ammo, "cast": cast_n.duplicate(), "shots": _last_shot(),
		"wind": k.rmb_winding(),
	}

## The id of the newest shot of the hunter's still in flight (a kit's own LMB, like darts, keeps no fire_cd).
func _last_shot() -> int:
	var last := -1
	for s in hunter.m.shots:
		if s["by"] == hunter:
			last = maxi(last, int(s["sid"]))
	return last

func _went_off(b: Dictionary, slot: String) -> bool:
	var now := _snap()
	var up := func(key: String) -> bool: return float(now[key]) > float(b[key]) + 0.0001
	var more := func(dict: String, key: String) -> bool:
		return float(now[dict].get(key, 0)) > float(b[dict].get(key, 0)) + 0.0001
	match slot:
		"lmb":
			var drew: bool = float(b["draw"]) < 0.0 and float(now["draw"]) >= 0.0
			return up.call("fire_cd") or up.call("swing") or up.call("mel") or up.call("shots") or drew \
					or int(now["ammo"]) < int(b["ammo"]) or more.call("cast", "primary")
		"rmb":
			return more.call("used", "utility") or more.call("cd", "rmb") or more.call("cast", "secondary") \
					or float(now["ch"]) < float(b["ch"]) or (bool(now["rmb_down"]) and not bool(b["rmb_down"])) \
					or (bool(now["wind"]) and not bool(b["wind"]))      # (a wind-up that throws by itself)
		"e":
			return more.call("used", "k1") or more.call("cd", "e") or up.call("e_t") or more.call("cast", "kin")
		"x":
			return more.call("used", "x") or more.call("cd", "x") or more.call("cast", "ultimate")
		"q":
			return up.call("gear")
	return false

# ------------------------------------------------------------------ combos with Shift and jump (item 51)
const ACT_S := 0.1              # s: owner rule, a jump or Shift out of an ability's recovery acts within this
const HOLD_PAST := 0.1          # s: a hold charges this long past the kit's tap/hold threshold before the move
const JUMP_RELEASE := 0.2       # s after take-off a hold is let go (still rising: in the air, short of auto-releases)
const KEEP_SPEED := 0.5         # share of the planar speed a release in the air keeps ("keeps your momentum")
const RMB_HELD := 0.2           # s: at most this long an RMB is held before the move
const HOLD_KEYS := {"lmb": "fire", "rmb": "sec_hold", "x": "x_down"}
const INTO_ACTS := ["fire", "cancel"]       # into rows whose move goes at once
const COMBINES := {"jump": ["fire"], "into": INTO_ACTS, "hold": ["keep"]}      # every other mode is an exception
const MODES_OF := {"jump": ["fire", "buffer"], "into": ["fire", "cancel", "buffer", "lock"], "hold": ["keep", "cancel"]}

var exceptions := {}            # hero -> its exception rows, printed at the end (the hero agents' worklist)

## Every ability against every move (DashFlow.MOVES): cast mid-jump, the move out of its recovery, and a hold of
## it carried through the move and let go in the air.
func _combos(m: Match, hero: String, slot: String) -> void:
	_mode(hero, "hold", slot, "mantle")         # (not a trial: a mantle row is checked for its reason and source)
	var got := _jump_cast(m, slot)
	var want := _mode(hero, "jump", slot, "")
	_judge(got == want, got, "%s jump -> %s: %s (row: %s)" % [hero, slot, got, want])
	for move in DashFlow.MOVES:
		var out := _out(m, slot, move)
		var row := _mode(hero, "into", slot, move)
		var right := (out == "act") == (row in INTO_ACTS) and (row != "lock" or out == "lost")
		_judge(right, out, "%s %s -> %s out of it: %s (row: %s)" % [hero, slot, move, out, row])
	if not HOLD_KEYS.has(slot) or not _is_hold(m, slot):
		return
	for move in DashFlow.MOVES:
		var kept := _hold(m, slot, move)
		var hrow := _mode(hero, "hold", slot, move)
		_judge(kept == hrow, kept, "%s hold %s through %s: %s (row: %s)" % [hero, slot, move, kept, hrow])

## A trial that couldn't be set up here ("n/a ...") is skipped, not judged.
func _judge(right: bool, got: String, what: String) -> void:
	if got.begins_with("n/a"):
		skipped += 1
		print("DASHFLOW skip %s" % what)
		return
	ok(right, what)

## The mode of one combo row; a row that isn't the default must be a known mode with a reason and a source.
func _mode(hero: String, kind: String, slot: String, move: String) -> String:
	var row: Dictionary
	match kind:
		"jump":
			row = DashFlow.jump_row_of(hero, slot)
		"into":
			row = DashFlow.into_row_of(hero, slot, move)
		_:
			row = DashFlow.hold_row_of(hero, slot, move)
	var mode := String(row["mode"])
	if not (mode in COMBINES[kind]):
		var label := ("%s %s %s" % [kind, slot, move]).strip_edges()
		ok(mode in MODES_OF[kind] and row["reason"] != "" and row["source"] != "",
				"%s exception %s: %s, reason and source given" % [hero, label, mode])
		var list: Array = exceptions.get(hero, [])
		list.append("%s: %s (%s)" % [label, mode, row["reason"]])
		exceptions[hero] = list
	return mode

## The exception rows per hero, deduplicated: what the hero agents review.
func _print_exceptions() -> void:
	for hero in exceptions:
		var seen := {}
		for line in exceptions[hero]:
			if not seen.has(line):
				seen[line] = true
				print("DASHFLOW exception %s %s" % [hero, line])

## _ready_up with a new kit: nothing the last trial left in the kit (a hammer out, a charge) carries over.
func _fresh(m: Match) -> void:
	_ready_up(m)
	hunter.set_arch(hunter.arch)
	_steps(m, 2)

## A press of `slot` near the top of a jump's rise: "fire" (went off in the air), "buffer" (went off once
## landed), "lost", or "n/a" (the jump never left the ground).
func _jump_cast(m: Match, slot: String) -> String:
	_fresh(m)
	hunter.inp["jump"] = true
	_steps(m, 9)
	if hunter.grounded:
		return "n/a: no jump"
	var before := _snap()
	_press(slot)
	for i in WATCH:
		m.step(Match.DT)
		hunter.inp["fire"] = false
		if _went_off(before, slot):
			return "fire" if not hunter.grounded or i == 0 else "buffer"
	return "lost"

## `slot` tapped, then the move pressed two steps after it went off (in its wind-up or recovery): "act" (the
## move went within ACT_S), "late" (later), "lost", or "n/a" (the slot doesn't go off here).
func _out(m: Match, slot: String, move: String) -> String:
	_fresh(m)
	if move == "air":
		_lift()
	var before := _snap()
	_press(slot)
	var went := false
	for i in 30:
		m.step(Match.DT)
		hunter.inp["fire"] = false
		if _went_off(before, slot):
			went = true
			break
	if not went:
		return "n/a: it doesn't go off here"
	_steps(m, 2)
	var moved := {"y": hunter.pos.y, "dashes": hunter.dashes, "ex": hunter.ex_cd, "roll": hunter.roll_t,
			"dashing": hunter.ak.in_dash()}
	hunter.inp["jump" if move == "jump" else "dash"] = true
	for i in 90:
		m.step(Match.DT)
		if _moved(moved, move):
			var after := float(i + 1) * Match.DT
			return "act" if after <= ACT_S + 0.001 else "late %.2fs" % after
	return "lost"

## Did the move go: a jump leaves the ground rising, a dash spends a charge (or the long dash) or starts a new
## dash or roll (one already running when Shift was pressed, like a flight, doesn't count).
func _moved(b: Dictionary, move: String) -> bool:
	if move == "jump":
		return hunter.vel.y > 0.5 and hunter.pos.y > float(b["y"]) + 0.01
	var spent := hunter.dashes < float(b["dashes"]) - 0.01 or hunter.ex_cd > float(b["ex"]) + 0.01
	var started := (hunter.ak.in_dash() and not bool(b["dashing"])) or hunter.roll_t > float(b["roll"]) + 0.01
	return spent or started

## Control: held past the kit's threshold then let go on the ground, does `slot` go off on the release?
func _is_hold(m: Match, slot: String) -> bool:
	return _hold(m, slot, "") == "keep"

## `slot` held, the move made with it still held (moving forward), then let go: right after a dash, or
## JUMP_RELEASE into a jump. "keep" (it went off on the release, and in the air kept KEEP_SPEED of the speed),
## "keep, stops" (went off but stopped the hunter), "cancel" (nothing came out), or "n/a" (it never started
## or went off by itself before the release).
func _hold(m: Match, slot: String, move: String) -> String:
	_fresh(m)
	hunter.inp["move"] = Vector2(0, -1)
	_hold_key(slot, true)
	var start := _snap()
	_steps(m, int((_threshold(slot) + HOLD_PAST) / Match.DT))
	if not _went_off(start, slot):
		return "n/a: it doesn't start holding"
	var mid := _snap()
	if move == "air":
		_lift()                 # (as if run off a ledge: a held RMB can't start in the air)
	_make(m, move)
	var before := _snap()
	if _released(mid, before, slot):
		return "n/a: it went off by itself before the release"
	var in_air := not hunter.grounded
	var speed := Vector2(hunter.vel.x, hunter.vel.z).length()
	_hold_key(slot, false)
	for i in 12:
		m.step(Match.DT)
		if _released(before, _snap(), slot):
			_steps(m, 3)
			var kept := Vector2(hunter.vel.x, hunter.vel.z).length()
			var after := move if move != "" else "a plain hold"
			var where := " in the air" if in_air else ""
			print("DASHFLOW note %s %s let go after %s%s: speed %.1f -> %.1f m/s" % [hunter.arch, slot, after, where,
					speed, kept])
			return "keep" if not in_air or kept >= speed * KEEP_SPEED else "keep, stops"
	return "cancel"

## The move made with a hold down: a dash to its end, or a jump JUMP_RELEASE into its rise.
func _make(m: Match, move: String) -> void:
	match move:
		"ground", "air":
			hunter.inp["dash"] = true
			m.step(Match.DT)
			for i in 60:
				if not hunter.ak.in_dash() and hunter.roll_t <= 0.0:
					break
				m.step(Match.DT)
		"jump":
			hunter.inp["jump"] = true
			_steps(m, int(JUMP_RELEASE / Match.DT))

## How long `slot` is held before the move: an LMB past its tap (the kit's data), an RMB briefly.
func _threshold(slot: String) -> float:
	match slot:
		"lmb":
			return float(hunter.ak.lmb_def().get("tap", 0.0))
		"rmb":
			# (any held RMB fires on its release; a long hold threshold would run into its auto-release mid-move)
			return minf(float(hunter.ak.rmb_def().get("hold", 0.0)), RMB_HELD)
	return 0.0

func _hold_key(slot: String, down: bool) -> void:
	hunter.inp[HOLD_KEYS[slot]] = down
	if slot == "rmb":
		hunter.inp["sec"] = down
	elif slot == "x" and down:
		HunterKeys.ult_pressed(hunter)

## Whether something came out between two snaps (a shot, a swing, a cast, a cooldown starting, a charge spent).
func _released(b: Dictionary, now: Dictionary, slot: String) -> bool:
	if slot == "lmb":
		for key in ["shots", "fire_cd", "swing"]:
			if float(now[key]) > float(b[key]) + 0.0001:
				return true
		return int(now["ammo"]) < int(b["ammo"]) or _more(b, now, "cast", "primary")
	if slot == "rmb":
		return _more(b, now, "cast", "secondary") or _more(b, now, "cd", "rmb") or _more(b, now, "used", "utility") \
				or float(now["ch"]) < float(b["ch"])
	return _more(b, now, "cast", "ultimate") or _more(b, now, "cd", "x") or _more(b, now, "used", "x")

func _more(b: Dictionary, now: Dictionary, dict: String, key: String) -> bool:
	return float(now[dict].get(key, 0)) > float(b[dict].get(key, 0)) + 0.0001
