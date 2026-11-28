extends RefCounted
## --combo-payoff-check: every mark-then-payoff pair of docs/heroes/combo_payoffs.md, through the kit's own
## payoff path. Each pair must show its tag on the foe (icon, time left inside the total) while the mark runs, and
## when the payoff lands the body flashes white and the combo sound plays (ComboMark.payoff does both).
## Then every other foe-carried state of the 13 kits (STATES): its icon in the plate status row, and the shared
## payoff path (ArchKit.payoff_fx, which CRUSHED, HAULED, the rock fall, the collapse and EXECUTED go through)
## flashing the body. Every payoff_fx call in the kits must name its victim, or its payoff has no flash.
## It prints a MARKSTATE table: kit, state, icon yes/no, flash yes/no.

const COMBO_SND := "combo"
const KITS_DIR := "res://scripts/arch/kits/"
const PAYOFF_ARGS := 5  # payoff_fx(at, col, snd, dir, victim)

## [kit, state, the plate status icon it must show]: states on a foe that no combo_read tag covers.
## Lace's Red Thread has no icon on purpose: it is a passive outline that follows the foe's health, with no timer.
const STATES := [
	["bulwark", "wall stun (CRUSHED)", "status_stunned"],
	["archer", "Heavy Shot pin (stun)", "status_stunned"],
	["dredge", "Anchor reel (Ground)", "status_grounded"],
	["dredge", "Blast (Blight)", "status_blight"],
	["dolm", "rock (Shred)", "status_shred"],
	["ostra", "Shard Snap (stun)", "status_stunned"],
	["ostra", "Trade (Disoriented)", "status_slowed"],
	["thief", "Primed shot (Shred)", "status_shred"],
	["juggernaut", "Warchain (Blight)", "status_blight"],
	["ashwick", "Char (Blight)", "status_blight"]
]

var main: Node
var ac  # the archetype check, for its match setup and stepping
var cm  # tools/combo_mark_check.gd: the mark and plain payoff for each kit
var n := 0
var fails := 0


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("PAYCHECK %-72s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	cm = load("res://tools/combo_mark_check.gd").new()
	for arch in ["thief", "gunslinger", "mage", "ashwick", "rimewright", "tender", "gil", "juggernaut"]:
		await _pair(arch, "")
	await _pair("gunslinger", "needle")
	await _pair("ashwick", "flashover")
	await _pair("rimewright", "knock")
	await _pair("juggernaut", "chain")
	for st in STATES:
		await _state(String(st[0]), String(st[1]), String(st[2]))
	_victims()
	print("PAYCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## One pair on a fresh strip: mark the foe, read the tag, land the payoff, read the flash and the sound.
func _pair(arch: String, via: String) -> void:
	var tag := "%s%s" % [arch, " (" + via + ")" if via != "" else ""]
	var r: Array = ac.setup(arch, 6.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: ArchKit = p.ak
	if via == "chain":
		(k as JuggernautKit).warchain._hook(t, t.pos)
	else:
		cm.apply(arch, k, t)
	var d := k.combo_read(t)
	ok(
		"%s: tag shows an icon and the time left" % tag,
		(
			not d.is_empty()
			and String(d["icon"]) != ""
			and float(d["left"]) > 0.0
			and float(d["left"]) <= float(d["total"])
		),
		str(d)
	)
	t.flash_t = 0.0
	Sfx.listener = p.pos  # the camera sets it each frame; a sound far from the origin is out of earshot
	var heard0 := int(Sfx.last_played.get(COMBO_SND, -1000))
	await main.get_tree().create_timer(0.05).timeout  # past the sound's own repeat gap
	_land(arch, via, ac, m, p, k, t)
	var stamp := float(t.get_meta(ComboMark.PAY_KEY, -9.0))
	ok(
		"%s: the payoff flashes the body white" % tag,
		absf(stamp - float(m.time)) < 0.1 and t.flash_t >= ComboMark.FLASH_BODY - 0.05,
		"stamp %.2f time %.2f flash %.3f" % [stamp, m.time, t.flash_t]
	)
	var heard := int(Sfx.last_played.get(COMBO_SND, -1000)) > heard0
	ok("%s: the payoff plays the combo sound" % tag, heard)
	_row_line(arch, via if via != "" else "tag", true, heard)
	ac.done(m)


func _land(arch: String, via: String, a, m: Match, p: Hunter, k: ArchKit, t: Hunter) -> void:
	match via:
		"needle":  # Longneedle down the lane through a Dazed foe
			a.aim_at(p, t.pos)
			(k as GunslingerKit)._fire_needle()
		"flashover":
			(k as AshwickKit).stoke(t)  # Ablaze stoked again: Flashover
		"knock":  # the knock on a Chilled foe: Shatter a beat later
			t.hp = 0.0
			(k as RimewrightKit).on_deal(t, 1.0, {})
			for i in 60:
				if t.has_meta(ComboMark.PAY_KEY):
					break
				a.step(m, 1.0 / 60.0)
		"chain":
			(k as JuggernautKit).warchain.pull()
		_:
			cm.payoff(arch, p, k, t)
			if arch == "juggernaut":
				a.step(m, 0.03)  # the knock lands a step after the hit


## One foe-carried state: the plate status row shows its icon, and the kit's payoff path flashes the body.
func _state(arch: String, what: String, icon: String) -> void:
	var r: Array = ac.setup(arch, 6.0, "", false)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	match icon:
		"status_stunned":
			t.stun_t = 2.0
		"status_grounded":
			KitStatus.apply(t, "gnd", 3.0, 0.0, false)
		"status_blight":
			KitStatus.apply(t, "blt", 4.0, 0.0, false)
		"status_shred":
			KitStatus.apply(t, "vul", 4.0, 0.25, false)
		"status_slowed":
			KitStatus.apply(t, "dsr", 3.0, 0.4, false)
	var row: Array = HudPlate.new().row(p, t, HudPlate.statuses(t))
	var shown := row.any(func(it): return it["icon"] == icon and float(it["left"]) > 0.0)
	ok("%s %s: %s shows on the plate row with time left" % [arch, what, icon], shown, str(row))
	t.flash_t = 0.0
	Sfx.listener = p.pos
	var heard0 := int(Sfx.last_played.get(COMBO_SND, -1000))
	await main.get_tree().create_timer(0.05).timeout
	p.ak.payoff_fx(t.pos, p.ak.res_col(), "", Vector2.ZERO, t)
	var stamp := float(t.get_meta(ComboMark.PAY_KEY, -9.0))
	var flashed := absf(stamp - float(m.time)) < 0.1 and t.flash_t >= ComboMark.FLASH_BODY - 0.05
	var heard := int(Sfx.last_played.get(COMBO_SND, -1000)) > heard0
	ok("%s %s: the payoff flashes the body and chimes" % [arch, what], flashed and heard)
	_row_line(arch, what, shown, flashed and heard)
	ac.done(m)


func _row_line(kit: String, state: String, icon: bool, flash: bool) -> void:
	var yn := ["no", "yes"]
	print("MARKSTATE %-12s %-28s icon=%s flash=%s" % [kit, state, yn[int(icon)], yn[int(flash)]])


## Every payoff_fx call in the kits passes all its arguments, the victim last (no victim: no body flash).
func _victims() -> void:
	var calls := 0
	var short: Array = []
	var dir := DirAccess.open(KITS_DIR)
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		for line in FileAccess.get_file_as_string(KITS_DIR + f).split("\n"):
			var at := line.find("payoff_fx(")
			if at < 0 or line.contains("func payoff_fx") or line.strip_edges().begins_with("#"):
				continue
			calls += 1
			var args := _arg_count(line.substr(at + "payoff_fx(".length()))
			if args < PAYOFF_ARGS:
				short.append("%s: %s" % [f, line.strip_edges()])
	ok("%d payoff_fx calls in the kits all name their victim" % calls, calls > 0 and short.is_empty(), str(short))


## Arguments in the text after a call's opening bracket, up to its matching close.
func _arg_count(text: String) -> int:
	var depth := 1
	var args := 1
	for ch in text:
		if ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth -= 1
			if depth == 0:
				return args
		elif ch == "," and depth == 1:
			args += 1
	return args
