extends RefCounted
## --tg-swap-dash-check: the owner's Training Grounds report of 11-16 (docs/decisions: none, a bug pass).
## 1. The Thief's out-of-charges dash on the ground flew ~11m (the long dash is the class's 5m): ThiefKit cut it
##    as if it were an air cartwheel and left its full speed unhanded. Now it is as long as everyone's long dash.
## 2. By design, kept (source parity, briefs/hero-ref/dancer.md "Aiming: cursor-placed"): the Thief's bolt ends at
##    the cursor, clamped to range; another hero's shot after a swap flies its own way.
## 3. A Shift press still buffered when you swap hunters went off as the new hunter's dash (Hunter.reclass now
##    drops it), so Joule's own press next found her one charge gone and did the long tumble.
## Prints TGSWAP PASS/FAIL; never touches the save.

var main: Node
var fails := 0
const DT := 1.0 / 60.0
const AIM := Vector3(10, 0, 0)

func ok(what: String, cond: bool, info := "") -> void:
	print("TGSWAP %-58s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9,
		"seed": 4242, "no_drop": true})
	m.set_process(false)
	var home: Vector3 = m.player.pos
	_dash_lengths(m, home)
	_bolt_ends(m, home)
	_swap_carry(m, home)
	print("TGSWAP DONE, failures: ", fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## Back on the spawn pad with everything charged.
func _ready_at(m: Match, home: Vector3) -> Hunter:
	var P: Hunter = m.player
	P.teleport(home)
	step(m, 1.5)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	return P

## Shift once toward +x (keys held for the press only); metres covered by the time the run has died out.
func _dash_len(m: Match, P: Hunter) -> float:
	var p0 := P.pos
	P.inp["aim"] = P.pos + AIM
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, DT)
	P.inp["move"] = Vector2.ZERO
	var t := DT
	while P.roll_t > 0.0 and t < 1.0:
		step(m, DT)
		t += DT
	step(m, 0.4)
	return (P.pos - p0).length()

func _dash_lengths(m: Match, home: Vector3) -> void:
	m.arena.set_arch("thief")
	var P := _ready_at(m, home)
	var short := _dash_len(m, P)
	ok("thief: a charged dash is the Cartwheel's 4.5 m", absf(short - 4.5) < 0.5, "%.2f m" % short)
	P = _ready_at(m, home)
	P.dashes = 0.0
	var long_d := _dash_len(m, P)
	var want := float(P.cdat.get("ex_dist", 5.0))
	ok("thief: with no charge left the long dash is the class's", absf(long_d - want) < 1.0,
		"%.2f m, class long dash %.1f m" % [long_d, want])
	m.arena.set_arch("mage")
	P = _ready_at(m, home)
	P.dashes = 0.0
	var mage_d := _dash_len(m, P)
	ok("thief long dash matches another hunter's (Joule)", absf(long_d - mage_d) < 1.0,
		"%.2f vs %.2f m" % [long_d, mage_d])

## The bolt's reach after a long cursor and a short one (the owner's second item).
func _bolt_reach(P: Hunter, m: Match, cursor_m: float) -> float:
	P.fire_cd = 0.0
	P.inp["aim"] = P.pos + Vector3(cursor_m, 0, 0)
	var n0 := m.shots.size()
	P.ak.lmb_override(true, DT)        # the held key, one frame: ThiefKit throws the bolt
	if m.shots.size() <= n0:
		return -1.0
	var sd: Dictionary = m.shots[-1]
	return float(sd["life"]) * (sd["vel"] as Vector2).length()

func _bolt_ends(m: Match, home: Vector3) -> void:
	m.arena.set_arch("thief")
	var P := _ready_at(m, home)
	var rng := float(P.wpn.get("range", 12.0))
	var near := _bolt_reach(P, m, 5.0)
	step(m, 0.8)
	var far := _bolt_reach(P, m, 40.0)
	ok("thief bolt (by design): stops at a near cursor", near > 0.0 and absf(near - 5.0) < 1.0, "%.1f m" % near)
	ok("thief bolt: flies to its range for a far cursor", far > 0.0 and absf(far - rng) < 1.0,
		"%.1f m of %.1f" % [far, rng])

func _swap_carry(m: Match, home: Vector3) -> void:
	m.arena.set_arch("thief")
	var P := _ready_at(m, home)
	P.inp["aim"] = P.pos + AIM
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	step(m, 0.05)
	P.do_dash()        # Shift again mid-flip: buffered for the flip's end
	ok("setup: the second Shift is waiting in the buffer", P.dash_buf > 0.0)
	m.arena.set_arch("mage")
	P.inp["move"] = Vector2.ZERO
	step(m, 0.3)
	var K: MageKit = P.ak
	ok("swap: no dash goes off by itself for Joule", K.wire.is_empty() and P.roll_t <= 0.0 and P.dashes >= 1.0,
		"charges %.1f" % P.dashes)
	P.do_dash()
	var wired := not K.wire.is_empty() and K.last_dash_kind != "ex"
	ok("swap: Joule's own first Shift is her Wirerun, not the tumble", wired, "wire held: %s" % wired)
