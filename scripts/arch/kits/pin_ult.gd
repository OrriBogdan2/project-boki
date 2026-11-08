class_name PinUlt
extends Node3D
## Hem's ultimate on X, Starpiercer (docs/heroes/archer.md; hero sheet pin.md "Ultimate"). The press is the
## first shot: the same frame X goes down a big arrow leaves the bow's nock point at the cursor, with no cast
## lock, wind-up or nock (the owner's 11-08 note: the ult fires on press, its effects alongside the shot, never before).
## It empowers the bow for "shots" (3) within "window" seconds: each LMB press after "recover" s looses the
## next arrow the instant it is pressed. Each flies "speed" m/s (the source's beam crosses its 18 m in about
## 0.2 s), pierces every foe out to "range" (1.5x her Empowered range), knocks back and strips "shred" armor.
## The last arrow hits harder and finishes a hunter it leaves under "execute" of their health. She can walk,
## roll and Spirit Walk between shots. The window ends after the last arrow or on time.
##
## Telegraphs (AimKit, own player): the arrow's lane out to its range and a ticked crosshair ring at her
## feet while empowered. Everyone sees pips over her for the shots left and her glowing bow, and hears the
## cast anywhere on the map (content/vfx/archer.json "ult_cast").
## Look: the empower burst, a flare at the bow per shot, the travelling arrow (PinFx kind "ult", sized to
## the hit width, red thread trail), a white burst cloud and a star on each hit, a bigger burst on the last.
## Bond: an arrow that hits a hunter goes to HeroUlt.landed once the hit has landed (a hit, or the knock or
## kill it caused); a miss pays nothing.

const RED := Color("ff2a3a")           # her thread
const CORE := Color("dfe6f0")          # the telegraph lane's silver core
const GOLD := Color("ffe27a")

var k: ArcherKit
var h: Hunter
var left := 0                  # empowered shots left (0: not empowered)
var window := 0.0              # s left in the empowered window
var recover := 0.0             # s before the next arrow can go
var fired := 0                 # (checks) arrows loosed, executions
var executes := 0
var _pips: Array = []
var _bow: MeshInstance3D

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h
	top_level = true
	name = "PinUlt"

func _ready() -> void:
	for i in 3:
		var pip := KitMeshes.inst(self, KitMeshes.quad(0.7, 0.7), KitShaders.mat("star", RED, true))
		KitShaders.param(pip, "power", 2.4)
		_pips.append(pip)
	_bow = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", RED, true))

func xd() -> Dictionary:
	return k.d.get("x", {})

func active() -> bool:
	return left > 0

## X pressed: the first arrow leaves this frame, then the bow stays empowered for the rest. A bow draw under
## way is dropped with no arrow. The cast's own flare and map-wide cue come with the shot, not before it.
func cast() -> bool:
	var x := xd()
	left = int(x.get("shots", 3))
	window = float(x.get("window", 6.0))
	recover = 0.0
	h.draw_t = -1.0
	k.draw.drop()
	_loose()
	k.vfx("ult_cast")
	return true

## Hunter.trigger while empowered: the bow is ours. A press (or a held button once recovered) is an arrow at
## once. False when not empowered (the normal bow runs).
func lmb(held: bool, dt: float) -> bool:
	if left <= 0:
		return false
	recover = maxf(0.0, recover - dt)
	if held and recover <= 0.0 and h.can_fire():
		_loose()
	return true

## Every step: the window, the telegraphs and the tells.
func tick(dt: float) -> void:
	if left > 0:
		window -= dt
		if window <= 0.0:
			end()
	if left <= 0:
		_tells(false)
		return
	var x := xd()
	AimKit.lane(h, "x", {"from": k.draw.bow_at(), "len": float(x.get("range", 18.0)),
		"width": float(x.get("width", 0.5)), "tip": true, "col": RED, "col2": CORE})
	AimKit.circle(h, "x_ring", {"self": true, "r": 0.9, "ticks": true, "star": true, "col": RED})
	_tells(true)

## Ends the empowered window (spent, timed out, or a merge): unused shots are lost.
func end() -> void:
	left = 0
	window = 0.0
	AimKit.hide(h, "x")
	AimKit.hide(h, "x_ring")
	_tells(false)

## A Boki merge: the empowered window ends with no arrow.
func drop() -> void:
	if left > 0:
		end()

## An arrow leaves the bow's nock point toward the cursor (the aim point, so the line is bow -> cursor).
func _loose() -> void:
	var x := xd()
	var last := left == 1
	recover = float(x.get("recover", 0.6))
	left -= 1
	fired += 1
	var start := k.draw.bow_at()
	var aim: Vector3 = h.inp.get("aim", h.pos)
	var dir := Vector2(aim.x - start.x, aim.z - start.z)
	dir = dir.normalized() if dir.length() > 0.05 else h.aim_dir()
	var rng := float(x.get("range", 18.0))
	var spd := float(x.get("speed", 140.0))
	var base := float(x.get("final_dmg", 40.0)) if last else float(x.get("dmg", 30.0))
	var dmg: float = base * k.m.dmg_mult(h) * LevelGrowth.ap(h)
	var arrow := {"last": last}
	var extra := {"src": "abil", "ab": "ultimate", "pierce": true, "hitset": {}, "kb": float(x.get("kb", 4.0)),
		"tracer": 0.0,
		"kx": func(_s: Dictionary, _at: Vector3, e: Ent, _why: String): _hit(e, arrow)}
	k.m.spawn_shot(h, start, dir * spd, dmg, rng / spd, 0.3, RED, extra)
	k.vfx("ult_beam", Vector3(start.x, h.pos.y, start.z), dir, {"last": last})
	k.play("pin_ult_final" if last else "pin_ult_loose")
	h.vel.x -= dir.x * 2.5
	h.vel.z -= dir.y * 2.5
	if left <= 0:
		end()

## An arrow passed through a foe: shred, the impact, the bond (HeroUlt.landed), the last arrow's execute.
func _hit(e: Ent, arrow: Dictionary) -> void:
	if e == null or not is_instance_valid(e):
		return
	var x := xd()
	if e is Hunter:
		var foe := e as Hunter
		foe.armor = maxf(0.0, foe.armor - float(x.get("shred", 10.0)))
		k.m.later(0.05, func(): if is_instance_valid(foe): HeroUlt.landed(k, foe))
	var big := bool(arrow["last"])
	k.vfx("ult_hit", e.pos, h.dir_to(e), {"last": big})
	if big and e is Hunter:
		var foe := e as Hunter
		k.m.later(0.03, func(): _execute(foe))

## The last arrow finishes a hunter it left under the execute share of their health.
func _execute(foe: Hunter) -> void:
	if not is_instance_valid(foe) or foe.dead or foe.downed or foe.out:
		return
	if foe.hp > foe.max_hp * float(xd().get("execute", 0.12)):
		return
	executes += 1
	var opts := {"src": "abil", "ab": "ultimate", "tags": ["ultimate", "execute"], "payoff": true}
	foe.hurt(foe.hp * 4.0 + foe.armor * 4.0, h, opts)
	HeroUlt.landed(k, foe)
	k.m.fx.own_look = true
	k.payoff_fx(foe.pos, "EXECUTED", GOLD, "pay_deadeye", h.dir_to(foe), foe)
	k.m.fx.own_look = false

## The tells everyone sees: three pips over her head (one per shot left) and a glow on the bow.
func _tells(on: bool) -> void:
	var show_it := on and k.tells_visible()
	var top := 2.4 * float(h.cdat.get("scale", 1.0)) + 0.35
	for i in _pips.size():
		var p: MeshInstance3D = _pips[i]
		p.visible = show_it and i < left
		if p.visible:
			p.global_position = h.position + Vector3((float(i) - 1.0) * 0.32, top, 0.0)
	_bow.visible = show_it
	if show_it:
		var rk := clampf(1.0 - recover / maxf(0.05, float(xd().get("recover", 0.6))), 0.0, 1.0)
		_bow.global_position = k.draw.bow_at()
		_bow.scale = Vector3.ONE * lerpf(0.7, 1.6, rk)
		KitShaders.param(_bow, "power", lerpf(0.8, 2.2, rk))
