class_name GunslingerUlt
extends RefCounted
## Vex's ultimate, Cinderfall (X). docs/heroes/gunslinger.md has the numbers and the research notes.
##
## One tap: the rifle snaps straight up and fires a shell into the sky. It comes down exactly where the cursor
## was (clamped to its range) after a fixed fall. Everyone sees the ground disc fill with its hot centre the whole
## time, a fair window to step out. The impact hits everyone on the disc, harder in the centre, and leaves a
## burning patch that hurts and slows for a few seconds. Vex is free to move and shoot throughout.

const FALL := "fall"
const BURN := "burn"
const DROP_T := 0.8              # s: the shell is seen falling through the column for the last part of the fall
const DROP_H := 16.0             # m: where the shell is first seen above the disc
const CHAR := Color("2a1018")    # the disc's scorched inside

var kit: GunslingerKit
var shells: Array = []         # {at, t, phase, node, tick, n}
var pool: Array = []           # shell nodes, reused
var casts := 0                 # (tests)
var impacts := 0
var zone_ticks := 0
var last := {}                 # (tests) the last impact: {at, hits, centre}

func _init(owner_kit: GunslingerKit) -> void:
	kit = owner_kit

func data() -> Dictionary:
	return kit.x_def()

## Damage scale for the ult: the hunter's own multiplier and level growth (it has no ranks).
func power() -> float:
	return kit.m.dmg_mult(kit.h) * LevelGrowth.ap(kit.h)

func running() -> bool:
	return not shells.is_empty()

# ------------------------------------------------------------------ the tap
## The cast (HeroUlt.press has checked the cooldown and that nothing holds her).
func cast() -> bool:
	var h := kit.h
	if not kit.needle.is_empty():
		return false
	var xd := data()
	var at := AimMode.point(h, float(xd["range"]))
	casts += 1
	var shell := {"at": at, "t": 0.0, "phase": FALL, "node": _take_node(), "tick": 0.0}
	shell["n"] = casts
	shells.append(shell)
	kit.play("gunslinger_x")
	# the shot goes straight up off the raised barrel; the disc and the column show at once
	var top := h.position + Vector3(0, 2.4, 0)
	kit.fx().star(top, GunslingerKit.EMBER, GunslingerKit.HOT, 1.4, 0.14)
	kit.fx().beam(top, top + Vector3(0, 14.0, 0), GunslingerKit.EMBER, GunslingerKit.HOT, 0.5, 0.3)
	kit.m.fx.flash(top, GunslingerKit.HOT, 1.2, 0.08)
	var r := float(xd["radius"])
	var delay := float(xd["delay"])
	kit.fx().disc(at, r, CHAR, GunslingerKit.DEEP, delay, GunslingerKit.EMBER)
	kit.fx().pillar(at, Color(GunslingerKit.EMBER, 0.4), GunslingerKit.HOT, 12.0, r * 0.55, delay, false)
	kit.m.sfx("vn_nuke_fire", h.pos, -1.0)
	kit.m.sfx("vn_nuke_fall", at, -2.0)
	kit.net_ring(at, r, GunslingerKit.EMBER)
	return true

## The shell: a big Burr Charge with its spikes out, made once and reused.
func _take_node() -> Node3D:
	for n in pool:
		if is_instance_valid(n) and not (n as Node3D).visible:
			(n as Node3D).visible = true
			return n
	var nn := kit._burr_mesh()
	nn.scale = Vector3.ONE * 2.6
	pool.append(nn)
	return nn

# ------------------------------------------------------------------ per step
func tick(dt: float) -> void:
	for s in shells.duplicate():
		s["t"] = float(s["t"]) + dt
		if String(s["phase"]) == FALL:
			_fall_tick(s)
		else:
			_burn_tick(s, dt)

## The disc fills toward the impact, its hot centre glows, a rivet ring closes in, and the shell drops through
## the column for the last part of the fall.
func _fall_tick(s: Dictionary) -> void:
	var xd := data()
	var at: Vector3 = s["at"]
	var delay := float(xd["delay"])
	var k := clampf(float(s["t"]) / delay, 0.0, 1.0)
	var disc := {"at": at, "r": float(xd["radius"]), "ticks": true, "fill": k, "core": float(xd["core_r"])}
	disc.merge({"all": true, "col": GunslingerKit.EMBER, "col2": GunslingerKit.DEEP, "hot": k * 0.6, "lw": 0.09})
	AimKit.circle(kit.h, "x%d" % int(s["n"]), disc)
	var rivets := {"at": at, "r": float(xd["radius"]) + 0.35 * (1.0 - k), "dashed": true, "all": true}
	rivets.merge({"col": GunslingerKit.BRONZE, "col2": GunslingerKit.HOT, "alpha": 0.6 + 0.6 * k})
	AimKit.circle(kit.h, "xr%d" % int(s["n"]), rivets)
	_drop_shell(s, delay)
	if float(s["t"]) >= delay:
		_impact(s)

func _drop_shell(s: Dictionary, delay: float) -> void:
	var n: Node3D = s["node"]
	var u := (float(s["t"]) - (delay - DROP_T)) / DROP_T
	if not is_instance_valid(n):
		return
	n.visible = u > 0.0 and u < 1.0
	if not n.visible:
		return
	var at: Vector3 = s["at"]
	var was := n.global_position
	n.global_position = at + Vector3(0, DROP_H * (1.0 - u * u), 0)
	n.rotation.y += 0.3
	if u > 0.05:
		kit.fx().smear(was + Vector3(0, 0.8, 0), n.global_position, GunslingerKit.DEEP, GunslingerKit.HOT, 0.7, 0.25)

func _impact(s: Dictionary) -> void:
	var xd := data()
	var h := kit.h
	var at: Vector3 = s["at"]
	var r := float(xd["radius"])
	var core_r := float(xd["core_r"])
	(s["node"] as Node3D).visible = false
	AimKit.hide(h, "x%d" % int(s["n"]))
	AimKit.hide(h, "xr%d" % int(s["n"]))
	s["phase"] = BURN
	s["t"] = 0.0
	impacts += 1
	_impact_fx(at, r)
	var dmg := float(xd["dmg"]) * power()
	var n := 0
	var centre := 0
	for f in kit.foes_in(at, r):
		var core: bool = Vector2(f.pos.x - at.x, f.pos.z - at.z).length() <= core_r + f.r * 0.5
		var o := {"src": "abil", "ab": "ult", "tags": ["ult", "cinderfall"], "crit": core}
		f.hurt(dmg * (1.0 + float(xd["core_k"]) if core else 1.0), h, o)
		HeroUlt.landed(kit, f)
		n += 1
		if core:
			centre += 1
	last = {"at": at, "hits": n, "centre": centre}
	if centre > 0:
		kit.m.fx.word(at + Vector3(0, 2.6, 0) + kit.fx().screen_up() * 1.2, "DEAD CENTRE", GunslingerKit.HOT, true)

## The impact: a white-hot flash column, an ember shock ring, a spray of embers, a boom, and the scorched
## patch with its burning rim that stays for the zone.
func _impact_fx(at: Vector3, r: float) -> void:
	var xd := data()
	var fx := kit.fx()
	fx.pillar(at, Color(GunslingerKit.HOT, 0.95), Color.WHITE, 10.0, r * 0.6, 0.3, true)
	fx.ring(at, r * 1.3, GunslingerKit.EMBER, GunslingerKit.HOT, 0.45)
	fx.ring(at, r * 0.7, GunslingerKit.HOT, GunslingerKit.EMBER, 0.3)
	fx.disc(at, r, CHAR, GunslingerKit.EMBER, float(xd["zone_t"]), GunslingerKit.EMBER)
	kit.m.fx.burst(at + Vector3(0, 0.5, 0), GunslingerKit.EMBER, 30, 9.0, 0.6, 6.0, 1.6)
	kit.m.fx.flash(at + Vector3(0, 1.0, 0), GunslingerKit.HOT, 3.0, 0.14)
	kit.net_ring(at, r, GunslingerKit.EMBER)
	kit.m.sfx("vn_nuke_boom", at, 1.0)
	kit.m.sfx("vn_nuke_burn", at, -6.0)
	Shake.incoming_big(kit.m, at, 0.6, kit.h)

## The burning patch: every tick it hurts and slows everyone on it; its rim stays lit for everyone and flames
## flicker across it. Ticks pay no bond (only the impact does).
func _burn_tick(s: Dictionary, dt: float) -> void:
	var xd := data()
	var at: Vector3 = s["at"]
	var r := float(xd["radius"])
	var rim := {"at": at, "r": r, "all": true, "col": GunslingerKit.EMBER, "col2": GunslingerKit.HOT, "lw": 0.08}
	rim["alpha"] = 1.0 - 0.5 * float(s["t"]) / float(xd["zone_t"])
	AimKit.circle(kit.h, "xz%d" % int(s["n"]), rim)
	_flames(at, r, dt)
	s["tick"] = float(s["tick"]) + dt
	if float(s["tick"]) >= float(xd["tick"]):
		s["tick"] = 0.0
		_zone_hit(at, r, xd)
	if float(s["t"]) >= float(xd["zone_t"]):
		AimKit.hide(kit.h, "xz%d" % int(s["n"]))
		shells.erase(s)

func _zone_hit(at: Vector3, r: float, xd: Dictionary) -> void:
	var dmg := float(xd["tick_dmg"]) * power()
	for f in kit.foes_in(at, r):
		var o := {"src": "abil", "ab": "ult", "tags": ["ult", "cinder_zone"], "slow": float(xd["slow_t"])}
		o["slow_k"] = float(xd["slow"])
		f.hurt(dmg, kit.h, o)
		zone_ticks += 1

func _flames(at: Vector3, r: float, dt: float) -> void:
	var rng := kit.fx().rng
	if rng.randf() > 20.0 * dt:
		return
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * r
	var p := kit.ground(at + Vector3(cos(a) * d, 0, sin(a) * d)) + Vector3(0, 0.1, 0)
	kit.m.fx.spark(p, Vector3.UP, GunslingerKit.EMBER, 3, 3.5, 25.0, 0.45, -2.0, 1.1)

# ------------------------------------------------------------------ ends
## A kit swap: shells in the air and burning patches go with the kit.
func clear() -> void:
	for s in shells:
		var n: Node3D = s["node"]
		if is_instance_valid(n):
			n.visible = false
		for id in ["x%d", "xr%d", "xz%d"]:
			AimKit.hide(kit.h, id % int(s["n"]))
	shells.clear()
