class_name PinUlt
extends Node3D
## Hem's ultimate on X, Starpiercer (docs/heroes/archer.md; hero sheet pin.md "Ultimate"). A tap with no
## cast lock empowers her next shots ("shots", 3) for "window" seconds. While empowered the bow needs no
## draw: each LMB press nocks for "nock" s (the bow glows, the cursor ring fills), then looses a beam
## that pierces every foe out to "range" (1.5x her Empowered range), knocks back and strips "shred"
## armor. The last beam hits harder and finishes a hunter it leaves under "execute" of their health.
## She can walk, roll and Spirit Walk between shots. The window ends after the last beam or on time.
##
## Telegraphs (AimKit, own player): the beam's lane out to its range and a ticked crosshair ring at her
## feet while empowered, the cursor ring filling through each nock. Everyone sees three pips over her
## and her glowing bow. Look (all pooled): the empower burst, a flat beam ribbon with a white core per
## shot that lasts 0.2 s, a white burst cloud and a star on each hit, a bigger burst on the last beam.
## Bond: a beam that hits a hunter goes to HeroUlt.landed once the hit has landed (a hit, or the knock or
## kill it caused); a miss pays nothing.

const RED := Color("ff2a3a")           # her thread
const CORE := Color("dfe6f0")          # the beam's silver core
const GOLD := Color("ffe27a")
const BEAM_T := 0.2            # s a beam ribbon stays up
const BEAMS := 3               # pooled beam ribbons

var k: ArcherKit
var h: Hunter
var left := 0                  # empowered shots left (0: not empowered)
var window := 0.0              # s left in the empowered window
var nock_t := -1.0             # s into the nock before a beam (-1: not nocking)
var recover := 0.0             # s before the next nock can start
var fired := 0                 # (checks) beams loosed, executions
var executes := 0
var _beams: Array = []         # pooled ribbons: {node, core, t}
var _pips: Array = []
var _bow: MeshInstance3D

func _init(kit: ArcherKit) -> void:
	k = kit
	h = kit.h
	top_level = true
	name = "PinUlt"

func _ready() -> void:
	for i in BEAMS:
		var rib := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", RED, true))
		var core := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", CORE, true))
		KitShaders.param(rib, "tail", 0.0)
		KitShaders.param(core, "tail", 0.0)
		_beams.append({"node": rib, "core": core, "t": 0.0})
	for i in 3:
		var pip := KitMeshes.inst(self, KitMeshes.quad(0.7, 0.7), KitShaders.mat("star", RED, true))
		KitShaders.param(pip, "power", 2.4)
		_pips.append(pip)
	_bow = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", RED, true))

func xd() -> Dictionary:
	return k.d.get("x", {})

func active() -> bool:
	return left > 0

## X pressed: empower the next shots. A bow draw under way is dropped with no arrow.
func cast() -> bool:
	var x := xd()
	left = int(x.get("shots", 3))
	window = float(x.get("window", 6.0))
	nock_t = -1.0
	recover = 0.0
	h.draw_t = -1.0
	k.draw.drop()
	k.vfx("ult_cast")
	k.play("pin_ult_cast")
	return true

## Hunter.trigger while empowered: the bow is ours. A press (or a held button once recovered) nocks;
## the nock ends in a beam. False when not empowered (the normal bow runs).
func lmb(held: bool, dt: float) -> bool:
	if left <= 0:
		return false
	if nock_t >= 0.0:
		nock_t += dt
		if nock_t >= float(xd().get("nock", 0.3)):
			_loose()
		return true
	recover = maxf(0.0, recover - dt)
	if held and recover <= 0.0 and h.can_fire():
		nock_t = 0.0
		k.play("pin_ult_nock")
		k.vfx("ult_nock")
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
	var nk := clampf(nock_t / float(x.get("nock", 0.3)), 0.0, 1.0) if nock_t >= 0.0 else 0.0
	AimKit.lane(h, "x", {"len": float(x.get("range", 18.0)), "width": float(x.get("width", 0.5)), "tip": true,
		"col": RED, "col2": CORE, "k": nk, "fill": nk, "hot": nk})
	AimKit.circle(h, "x_ring", {"self": true, "r": 0.9, "ticks": true, "star": true, "col": RED})
	if nock_t >= 0.0:
		AimKit.charge(h, nk, {"col": RED, "col2": CORE})
	_tells(true)

## Ends the empowered window (spent, timed out, or a merge): unused shots are lost.
func end() -> void:
	left = 0
	window = 0.0
	nock_t = -1.0
	AimKit.hide(h, "x")
	AimKit.hide(h, "x_ring")
	_tells(false)

## A Boki merge: the nock and the empowered window both end with no beam.
func drop() -> void:
	if left > 0:
		end()

func _loose() -> void:
	var x := xd()
	var last := left == 1
	nock_t = -1.0
	recover = float(x.get("recover", 0.6))
	left -= 1
	fired += 1
	var dir := h.aim_dir()
	var rng := float(x.get("range", 18.0))
	var spd := float(x.get("speed", 140.0))
	var base := float(x.get("final_dmg", 40.0)) if last else float(x.get("dmg", 30.0))
	var dmg: float = base * k.m.dmg_mult(h) * LevelGrowth.ap(h)
	var start := h.pos + Vector3(dir.x * 0.6, 0.95 * float(h.cdat.get("scale", 1.0)), dir.y * 0.6)
	var beam := {"last": last}
	var extra := {"src": "abil", "ab": "ultimate", "pierce": true, "hitset": {}, "kb": float(x.get("kb", 4.0)),
		"tracer": 0.0,
		"kx": func(_s: Dictionary, _at: Vector3, e: Ent, _why: String): _hit(e, beam)}
	k.m.spawn_shot(h, start, dir * spd, dmg, rng / spd, 0.3, RED, extra)
	var length := _beam_len(start, dir, rng)
	_show_beam(start, dir, length, last)
	k.vfx("ult_beam", Vector3(start.x, h.pos.y, start.z), dir, {"len": length, "last": last})
	k.play("pin_ult_final" if last else "pin_ult_loose")
	h.vel.x -= dir.x * 2.5
	h.vel.z -= dir.y * 2.5
	if left <= 0:
		end()

## A beam passed through a foe: shred, the impact, the bond (HeroUlt.landed), the last beam's execute.
func _hit(e: Ent, beam: Dictionary) -> void:
	if e == null or not is_instance_valid(e):
		return
	var x := xd()
	if e is Hunter:
		var foe := e as Hunter
		foe.armor = maxf(0.0, foe.armor - float(x.get("shred", 10.0)))
		k.m.later(0.05, func(): if is_instance_valid(foe): HeroUlt.landed(k, foe))
	var big := bool(beam["last"])
	k.vfx("ult_hit", e.pos, h.dir_to(e), {"last": big})
	if big and e is Hunter:
		var foe := e as Hunter
		k.m.later(0.03, func(): _execute(foe))

## The last beam finishes a hunter it left under the execute share of their health.
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

## How far the beam's ribbon reaches before a wall stops it (the shot itself stops there too).
func _beam_len(start: Vector3, dir: Vector2, rng: float) -> float:
	var d := 0.5
	while d < rng:
		var q := start + Vector3(dir.x, 0, dir.y) * d
		var g: float = k.m.world.ground_at(q.x, q.z)
		if k.m.world.is_block(q.x, q.z) or g > start.y:
			return d
		d += 0.4
	return rng

func _show_beam(start: Vector3, dir: Vector2, length: float, big: bool) -> void:
	var slot: Dictionary = _beams[fired % BEAMS]
	slot["t"] = BEAM_T
	var mid := start + Vector3(dir.x, 0, dir.y) * length * 0.5
	var yaw := atan2(-dir.y, dir.x)
	var w := 0.75 if big else 0.6
	for key in ["node", "core"]:
		var n: MeshInstance3D = slot[key]
		n.visible = true
		n.global_position = mid
		n.rotation = Vector3(-PI * 0.5, yaw, 0.0)
		var cw := w if key == "node" else w * 0.35
		n.scale = Vector3(length, cw, 1.0)

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
		var d := h.aim_dir()
		var nk := clampf(nock_t / float(xd().get("nock", 0.3)), 0.0, 1.0) if nock_t >= 0.0 else 0.0
		_bow.global_position = h.position + Vector3(d.x * 0.6, 1.1 * float(h.cdat.get("scale", 1.0)), d.y * 0.6)
		_bow.scale = Vector3.ONE * lerpf(0.7, 1.6, nk)
		KitShaders.param(_bow, "power", lerpf(0.8, 2.2, nk))

func _process(delta_in: float) -> void:
	var delta := minf(delta_in, 1.0 / 30.0)
	for slot in _beams:
		if float(slot["t"]) <= 0.0:
			continue
		slot["t"] = float(slot["t"]) - delta
		var life := clampf(float(slot["t"]) / BEAM_T, 0.0, 1.0)
		for key in ["node", "core"]:
			var n: MeshInstance3D = slot[key]
			n.visible = life > 0.0
			KitShaders.param(n, "power", 1.8 * life)
