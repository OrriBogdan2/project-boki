class_name JuggernautUlt
extends RefCounted
## Zedran's ultimate on X, Gilded Riposte (his "x" data in content/archetypes/juggernaut.json; the source's
## Retaliation, briefs/hero-ref/juggernaut.md "Ultimate (on X)"). Press: he plants in a guard for 0.65s,
## blade upright and his body flaring gold, taking no damage and no crowd control (each hit he blocks rings
## out and makes the answer harder, up to two). Then he lunges 1.8m and cleaves up through the strip ahead
## (1.8m wide, 3.6m long, shown to everyone through the guard): he heals 80% of what it deals, and knocking a
## hunter with it makes it ready again at once. Landing it on a rival hunter fills the bond meter
## (HeroUlt.landed: a hit, a knock or a kill, the best of the cast). Owned by JuggernautKit.

const GOLD := Color("ffc94a")          # the guard's glow and the cleave's outer edge (the source's is red)
const HOT := Color("ffe39a")           # the cleave's inner fill and the impact cloud: his gold, run hot
const LANE_COL := Color("ffb820")      # the strip ahead: his gold
const BLOCK_GAP := 0.08                # s: hits closer together than this (one shotgun blast) count once

var k: JuggernautKit
var st := {}                           # running: {phase: guard|strike|recover, t, dir, from, blocks, last_block}
var glow: Node3D = null                # the gold guard shell (built once, shown while guarding)
var casts := 0                         # (tests, demo)
var strikes := 0                       # cleaves that hit someone
var blocked := 0                       # hits blocked over the run
var resets := 0                        # knocks that made it ready again
var last_dealt := 0.0
var last_healed := 0.0

func _init(kit: JuggernautKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.x_def()

func running() -> bool:
	return not st.is_empty()

func guarding() -> bool:
	return String(st.get("phase", "")) == "guard"

## Planted from the press until the cleave has landed (the recovery lets him walk again, slowly, and a jump or
## Shift moves him straight out of it).
func move_k() -> float:
	match String(st.get("phase", "")):
		"guard", "strike": return 0.0
		"recover": return 0.5
	return 1.0

## X pressed: the guard goes up at once.
func start() -> void:
	var h := k.h
	casts += 1
	st = {"phase": "guard", "t": 0.0, "dir": h.aim_dir(), "blocks": 0, "last_block": -9.0}
	k.play("jug_guard")
	_show_glow(true)
	k.m.fx.word(h.pos + Vector3(0, 2.7, 0), String(data()["short"]).to_upper(), GOLD, false)
	k.m.sfx("jug_guard", h.pos, -2.0 if h.is_local() else -5.0, 1.0)

## A merge or a knock ends it at once, with no strike.
func drop() -> void:
	st = {}
	_show_glow(false)
	AimKit.hide(k.h, "ult")

func tick(dt: float) -> void:
	if st.is_empty():
		return
	var h := k.h
	if h.downed or h.out:
		drop()
		return
	var d := data()
	st["t"] = float(st["t"]) + dt
	match String(st["phase"]):
		"guard":
			_tick_guard(d)
		"strike":
			if float(st["t"]) >= float(d["strike_t"]):
				_land(d)
		"recover":
			if float(st["t"]) >= float(d["recover"]):
				drop()
			elif not h.grounded:
				drop()               # a jump moves him out of it (Shift drops it in JuggernautKit.on_dash)
				k.play("")           # the jump's own pose eases in over the follow-through

## The guard: planted (no jumping off either), the strip ahead follows the aim, gold sparks rise off him.
func _tick_guard(d: Dictionary) -> void:
	var h := k.h
	if h.vel.y > 0.0:
		h.vel.y = 0.0          # no jumping off the guard (it lands straight back)
	var aim := h.aim_dir()
	if aim.length() > 0.1:
		st["dir"] = aim.normalized()
	var gk := clampf(float(st["t"]) / float(d["guard"]), 0.0, 1.0)
	AimKit.lane(h, "ult", {"dir": st["dir"], "len": float(d["len"]), "width": float(d["width"]), "fill": gk,
			"col": LANE_COL, "col2": GOLD, "all": true, "alpha": 1.3})
	if randf() < 0.5:
		k.m.fx.spark(h.pos + Vector3(randf_range(-0.4, 0.4), 0.6 + randf() * 1.2, randf_range(-0.4, 0.4)), Vector3.UP,
				GOLD, 2, 2.5, 40.0, 0.3, -2.0, 0.8)
	if float(st["t"]) >= float(d["guard"]):
		_strike(d)

## The guard ends: he lunges along the strip and the blade comes up through it.
func _strike(d: Dictionary) -> void:
	var h := k.h
	var dir: Vector2 = st["dir"]
	st["phase"] = "strike"
	st["t"] = 0.0
	st["from"] = h.pos
	_show_glow(false)
	AimKit.hide(h, "ult")
	k.play("jug_riposte")
	k.travel(float(d["lunge"]), float(d["strike_t"]), {"invuln": 0.0, "trail": "dust", "dir": dir})
	k.m.sfx("jug_riposte", h.pos, -1.0 if h.is_local() else -4.0, 1.0)

## The cleave lands: everyone in the strip (from where the guard stood) is hit once.
func _land(d: Dictionary) -> void:
	var h := k.h
	var dir: Vector2 = st["dir"]
	var from: Vector3 = st["from"]
	st["phase"] = "recover"
	st["t"] = 0.0
	h.roll_t = 0.0
	var blocks := int(st["blocks"])
	var dmg := float(d["dmg"]) * (1.0 + float(d["block_k"]) * float(blocks)) * k.power("x")
	var mid := from + Vector3(dir.x, 0, dir.y) * float(d["len"]) * 0.55
	k.fx().crescent(mid + Vector3(0, 1.0, 0), dir, 150.0, float(d["len"]) * 0.6, GOLD, HOT, 0.24, PI * 0.5)
	last_dealt = 0.0
	for f in k.m.foes_of(h.team):
		if not f.hittable() or absf(f.pos.y - from.y) > 2.0:
			continue
		if not AimMode.in_lane(from, dir, float(d["len"]), float(d["width"]), f.pos, f.r):
			continue
		var hit := {"src": "abil", "ab": "ult", "tags": ["riposte"], "kb": dir * 6.0, "crit": true}
		var dealt: float = f.hurt(dmg, h, hit)
		if dealt <= 0.0:
			continue
		last_dealt += dealt
		_impact(f, dir, dealt)
		if f is Hunter and ((f as Hunter).downed or f.hp <= 0.0):
			_reset()
		HeroUlt.landed(k, f)
	if last_dealt > 0.0:
		strikes += 1
		var hp0 := h.hp
		h.heal(last_dealt * float(d["heal"]))
		last_healed = h.hp - hp0
		if last_healed >= 1.0:
			k.fx().pillar(h.pos, Color("ffd27a"), 2.6, 0.5, 0.5)

## On someone hit: the gold impact cloud, the hit-stop and a heavy shake.
func _impact(f: Ent, dir: Vector2, dealt: float) -> void:
	var h := k.h
	k.fx().star(f.pos + Vector3(0, 1.2, 0), GOLD, 2.4, 0.3, HOT)
	k.m.fx.burst(f.pos + Vector3(0, 0.8, 0), Color(HOT, 0.85), 22, 3.0, 0.6, -1.0, 1.6)
	k.m.fx.burst(f.pos + Vector3(0, 1.0, 0), GOLD, 12, 6.0, 0.35, 4.0, 1.0, Vector3(dir.x, 0.6, dir.y), 50.0)
	Feel.hitstop(k.m, h, f, dealt, {"melee": true, "payoff": true, "heavy": true})
	Feel.shake(k.m, "t4", h, f.pos, f)
	if h.is_local():
		Oomph.punch_dir(k.m, dir, 0.3)

## A hunter knocked by the cleave: it is ready again at once.
func _reset() -> void:
	resets += 1
	k.cd["x"] = 0.0
	k.m.fx.word(k.h.pos + Vector3(0, 2.6, 0), "RIPOSTE READY", GOLD, true)
	k.m.sfx("unlock", k.h.pos, -4.0, 1.4)

## A hit arriving during the guard: blocked (no damage, no crowd control). A fall into the abyss still
## counts. Returns true when it was blocked.
func block(by: Ent, o: Dictionary) -> bool:
	if not guarding() or String(o.get("src", "")) == "fall":
		return false
	var h := k.h
	var now: float = k.m.time
	if now - float(st["last_block"]) >= BLOCK_GAP:
		st["last_block"] = now
		blocked += 1
		st["blocks"] = mini(int(st["blocks"]) + 1, int(data()["blocks_max"]))
		var from := by.pos if by != null and is_instance_valid(by) else h.pos + Vector3(0, 0, -1)
		var to := Vector3(from.x - h.pos.x, 0.3, from.z - h.pos.z).normalized()
		k.m.fx.spark(h.pos + Vector3(0, 1.2, 0) + to * 0.5, to, HOT, 10, 9.0, 40.0, 0.2, 0.0, 1.1)
		k.m.fx.word(h.pos + Vector3(0, 2.3, 0), "BLOCKED", GOLD, false)
		k.m.sfx("jug_ting", h.pos, -3.0, 1.0 + 0.08 * float(st["blocks"]))
	return true

## The gold shell over him while he guards (one node per hunter, shown and hidden).
func _show_glow(on: bool) -> void:
	if glow == null or not is_instance_valid(glow):
		if not on:
			return
		glow = _make_glow()
	glow.visible = on

func _make_glow() -> Node3D:
	var n := Node3D.new()
	var shell := MeshInstance3D.new()
	# a gold shell hugging the body, alpha blended so it stays gold on grass; no light (it pooled into a pale
	# disc on the ground round his feet)
	shell.mesh = Models.sphere(0.7, 16)
	shell.material_override = DJFx.solid(Color(GOLD, 0.3))
	shell.scale = Vector3(1.0, 1.5, 1.0)
	shell.position.y = 1.05
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(shell)
	k.h.add_child(n)
	k.self_nodes.append(n)
	return n
