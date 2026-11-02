class_name DredgeBlast
extends RefCounted
## Dredge's ultimate on X, Brass Broadside (docs/heroes/dredge.md): one press plants him for a 1.1s charge
## while a 105 degree fan grows on the ground in front (everyone sees it; it is the exact area, locked at the
## press), then two waves 0.6s apart of six heavy brass slugs each (real shots, Match.spawn_shot) with
## Anti-Heal. Up close every slug lands; further out only the middle ones do. A stun during the charge stops
## it; a stun after the first wave stops the second. A slug that hits, knocks or kills an enemy hunter fills
## the Boki bond (HeroUlt.landed: the best event of the cast counts, not each slug).

const MUZZLE := 0.9                 # m in front of his chest where the slugs leave his hands
const RECOVER := 0.3                # s he stays planted after the last wave
const WAVE_COL := [Color("ffb85a"), Color("a07aff")]     # wave 1 brass gold, wave 2 violet
const WAVE_CORE := [Color("fff0c0"), Color("ffe0a0")]
const WAVE_PITCH := [1.0, 0.82]
const FAN_COL := Color("ffcf70")          # Dredge's brass, the anchor's colour

var k: DredgeKit
var h: Hunter
var m: Node
var blast := {}                     # hold: the charge and its waves {t, dir, fired}
var casts := 0                      # (tests)
var waves := 0
var slug_hits := 0
var stopped := 0
var last_wave_hits: Array = []      # slug hits per wave of the last cast

func _init(kit: DredgeKit) -> void:
	k = kit
	h = kit.h
	m = kit.m

func xd() -> Dictionary:
	return k.x_def()

func running() -> bool:
	return not blast.is_empty()

## Is he still charging (no wave out yet)?
func charging() -> bool:
	return running() and int(blast["fired"]) == 0

func start() -> bool:
	if running():
		return false
	blast = {"t": 0.0, "dir": h.aim_dir(), "fired": 0}
	last_wave_hits = []
	casts += 1
	k.play("dr_blast")
	m.sfx("dr_blast_charge", h.pos, -2.0, 1.0)
	return true

## A Boki merge: the charge or the waves left never fire.
func drop() -> void:
	if not running():
		return
	blast = {}
	AimKit.hide(h, "x_fan")
	k.play("")

func tick(dt: float) -> void:
	if not running():
		return
	if h.stun_t > 0.0 or h.downed or h.out:
		_stop()
		return
	var x := xd()
	blast["t"] = float(blast["t"]) + dt
	var t := float(blast["t"])
	var charge := float(x["charge"])
	if t < charge:
		_charge_looks(t / charge)
	var n := int(x["waves"])
	var fired := int(blast["fired"])
	if fired < n and t >= charge + float(x["gap"]) * fired:
		blast["fired"] = fired + 1
		_wave(fired)
	if int(blast["fired"]) >= n and t >= charge + float(x["gap"]) * (n - 1) + RECOVER:
		blast = {}

## Interrupted: nothing more fires. Stopped before the first wave, it comes back soon (the counterplay).
func _stop() -> void:
	if charging():
		k.cd["x"] = minf(float(k.cd["x"]), float(xd()["stop_cd"]))
	stopped += 1
	blast = {}
	AimKit.hide(h, "x_fan")
	k.play("")
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "STOPPED", Color("ff8a7a"), true)
	m.sfx("warn", h.pos, -4.0, 0.8)

## The charge: the fan grows out from his front over 1.1s, brass sparks crackle between his fists.
func _charge_looks(kc: float) -> void:
	var x := xd()
	var grow := 1.0 - pow(1.0 - kc, 2.0)
	var reach := maxf(0.6, float(x["range"]) * grow)
	AimKit.cone(h, "x_fan", {"dir": blast["dir"], "len": reach, "deg": float(x["fan_deg"]),
		"fill": kc, "all": true, "col": FAN_COL, "col2": WAVE_COL[1], "alpha": 1.1, "hot": 0.4 * kc})
	if not k.tells_visible() or randf() > 0.5:
		return
	var hand_l := _hand(-1.0)
	var hand_r := _hand(1.0)
	m.fx.bolt(hand_l, hand_r + Vector3(0, randf_range(-0.2, 0.2), 0), Color(WAVE_COL[1], 0.9))
	k.fx.orb((hand_l + hand_r) * 0.5, WAVE_COL[0], WAVE_CORE[0], 0.3 + 0.5 * kc, 0.08)

func _hand(side: float) -> Vector3:
	var d2: Vector2 = blast["dir"]
	var f := Vector3(d2.x, 0, d2.y)
	return h.pos + Vector3(0, 1.1, 0) + f * 0.5 + f.cross(Vector3.UP) * 0.3 * side

## One wave: six slugs fanned evenly across the locked fan, out to its edge.
func _wave(i: int) -> void:
	var x := xd()
	waves += 1
	last_wave_hits.append(0)
	var dir: Vector2 = blast["dir"]
	var f3 := Vector3(dir.x, 0, dir.y)
	var at := h.pos + Vector3(0, 1.0, 0) + f3 * MUZZLE
	var n := int(x["orbs"])
	var fan := float(x["fan_deg"])
	var speed := float(x["speed"])
	var life := maxf(0.05, float(x["range"]) - MUZZLE) / speed
	var dmg := float(x["dmg"]) * k.power("x")
	for j in n:
		var ang := deg_to_rad(-fan * 0.5 + fan * float(j) / float(maxi(1, n - 1)))
		var d := dir.rotated(ang)
		var cb := func(_s: Dictionary, _at: Vector3, e: Ent, why: String) -> void: _slug_hit(i, e, why, dmg)
		m.spawn_shot(h, at, d * speed, 0.0, life, float(x["size"]), WAVE_COL[i % 2], {"kx": cb})
		if k.tells_visible():
			k.fx.ride(m.shots[-1], "orb", WAVE_COL[i % 2], WAVE_CORE[i % 2], 0.9, 0.5)
	_wave_fx(i, at, dir)

func _slug_hit(wave: int, e: Ent, why: String, dmg: float) -> void:
	if e == null or not is_instance_valid(e) or e.dead or e.team == h.team or not (why in ["hit", "pass"]):
		return
	slug_hits += 1
	last_wave_hits[wave] = int(last_wave_hits[wave]) + 1
	e.hurt(dmg, h, {"src": "abil", "ab": "ult", "tags": ["ult", "slug"]})
	KitStatus.apply(e, "blt", float(xd()["blt_t"]))
	k.fx.orb(e.pos + Vector3(0, 1.0, 0), WAVE_COL[wave % 2], WAVE_CORE[wave % 2], 0.9, 0.1)
	m.fx.burst(e.pos + Vector3(0, 0.6, 0), Color("b48aff"), 4, 2.0, 0.5, -4.0, 0.8, Vector3.UP, 20.0)
	HeroUlt.landed(k, e)

## A wave goes: a brass sunburst at his fists, a crescent sweep across the fan, a heavy thump and a shove
## of the camera back toward him.
func _wave_fx(i: int, at: Vector3, dir: Vector2) -> void:
	var x := xd()
	k.fx.sunburst(at, 1.3, WAVE_COL[i % 2], WAVE_CORE[i % 2], 0.18, true)
	k.fx.crescent(
		h.pos + Vector3(0, 0.3, 0), dir, float(x["fan_deg"]), float(x["range"]), WAVE_CORE[i % 2], WAVE_COL[i % 2],
		0.22
	)
	AimKit.cone(h, "x_fan", {"dir": dir, "len": float(x["range"]), "deg": float(x["fan_deg"]), "edges": true,
		"all": true, "col": FAN_COL, "alpha": 0.8, "dur": 0.25})
	m.sfx("dr_blast", h.pos, 0.0, WAVE_PITCH[i % 2])
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local():
		Oomph.punch_dir(m, -dir, 0.2)
	k.net_ring(at, float(x["range"]) * 0.5, WAVE_COL[i % 2])
