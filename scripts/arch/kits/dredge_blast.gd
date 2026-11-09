class_name DredgeBlast
extends RefCounted
## Dredge's ultimate on X, Brass Broadside (docs/heroes/dredge.md): one press starts a 1.1s charge while a 105
## degree fan grows on the ground in front (everyone sees it; it is the exact area, turning with his aim), then
## two waves 0.6s apart of six heavy brass slugs each (real shots, Match.spawn_shot) with Anti-Heal. He can walk
## slowly throughout (x.charge_move, then x.fire_move of his speed; CastHold) and keeps turning to the cursor.
## Up close every slug lands; further out only the middle ones do. A stun during the charge stops it; a stun
## after the first wave stops the second. A slug that hits, knocks or kills an enemy hunter fills
## the Boki bond (HeroUlt.landed: the best event of the cast counts, not each slug).

const MUZZLE := 0.9                 # m in front of his chest where the slugs leave his hands
const RECOVER := 0.3                # s the slowed walk lasts after the last wave
# the slugs in flight: pale coin gold (their trail is HeroVfx "slug")
static var SLUG_COL := HeroVfx.col("dredge", "hot")
const WAVE_PITCH := [1.0, 0.82]
## the fan on the ground: coin gold (the signature), and how strong its fill and rim are over AimKit's defaults
static var FAN_COL := DredgeKit.ANCHOR_COL
static var FAN_HOT := HeroVfx.col("dredge", "hot")
const FAN_ALPHA := 1.8

var k: DredgeKit
var h: Hunter
var m: Node
var blast := {}                     # hold: the charge and its waves {t, dir, fired}
var hold: CastHold                  # his slowed walk while it charges and fires
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
	hold = CastHold.hover_slow(h, float(xd()["charge_move"]))
	last_wave_hits = []
	casts += 1
	k.play("dr_blast")
	m.sfx("dr_blast_charge", h.pos, -2.0, 1.0)
	return true

## His share of run speed while it runs: slow through the charge, slower while the waves go.
func move_k() -> float:
	return hold.slow_k if running() else 1.0

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
	blast["dir"] = h.aim_dir()          # the fan and the waves follow the cursor
	var t := float(blast["t"])
	var charge := float(x["charge"])
	if t < charge:
		_charge_looks(t / charge)
	var n := int(x["waves"])
	var fired := int(blast["fired"])
	if fired < n and t >= charge + float(x["gap"]) * fired:
		blast["fired"] = fired + 1
		hold.slow_k = float(x["fire_move"])
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
		"fill": kc, "all": true, "col": FAN_COL, "col2": FAN_HOT, "alpha": FAN_ALPHA, "hot": 0.15 * kc})
	if k.tells_visible():
		HeroVfx.of(m).hold(h, "broadside_charge", kc, {"r": float(x["range"])})     # gold gathers in his fists

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
		var cb := func(_s: Dictionary, _at: Vector3, e: Ent, why: String) -> void: _slug_hit(e, why, dmg)
		m.spawn_shot(h, at, d * speed, 0.0, life, float(x["size"]), SLUG_COL, {"kx": cb})
		if k.tells_visible():
			HeroVfx.of(m).trail(h, "slug", m.shots[-1]["node"])
	_wave_fx(i, at, dir)

func _slug_hit(e: Ent, why: String, dmg: float) -> void:
	if e == null or not is_instance_valid(e) or e.dead or e.team == h.team or not (why in ["hit", "pass"]):
		return
	slug_hits += 1
	last_wave_hits[-1] = int(last_wave_hits[-1]) + 1
	e.hurt(dmg, h, {"src": "abil", "ab": "ult", "tags": ["ult", "slug"]})
	KitStatus.apply(e, "blt", float(xd()["blt_t"]))
	k.vfx("broadside_hit", e.pos)
	HeroUlt.landed(k, e)

## A wave goes: a gold flash at his fists, a sweep across the fan with coins and sparks flying out, a heavy thump
## and a shove of the camera back toward him.
func _wave_fx(i: int, at: Vector3, dir: Vector2) -> void:
	var x := xd()
	k.vfx("broadside_wave", at, dir, {"r": float(x["range"]), "flip": i % 2 == 1})
	AimKit.cone(h, "x_fan", {"dir": dir, "len": float(x["range"]), "deg": float(x["fan_deg"]), "edges": true,
		"all": true, "col": FAN_COL, "alpha": FAN_ALPHA, "dur": 0.25})
	m.sfx("dr_blast", h.pos, 0.0, WAVE_PITCH[i % 2])
	k.net_ring(at, float(x["range"]) * 0.5, FAN_COL)
