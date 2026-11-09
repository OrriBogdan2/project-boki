class_name JuggernautUlt
extends RefCounted
## Kael's ultimate on X, Gilded Riposte (his "x" data in content/archetypes/juggernaut.json; the source's
## Retaliation, briefs/hero-ref/juggernaut.md "Ultimate (on X)"). Press: he plants in a guard for 0.65s,
## blade upright and his body flaring gold, taking no damage and no crowd control (each hit he blocks rings
## out and makes the answer harder, up to two). Then he lunges 1.8m and cleaves up through the strip ahead
## (1.8m wide, 3.6m long, shown to everyone through the guard): he heals 80% of what it deals. Taking a hunter
## down with it (the source's "killing a living enemy": our lethal hit is a knock; a hunter already down takes
## nothing from it, and a monster or a wisp doesn't count) makes it ready again at once. Landing it on a
## rival hunter fills the bond meter (HeroUlt.landed: a hit, a knock or a kill, the best of the cast). A chain
## still held pulls him through it: E in the guard or the cleave hauls him along the chain, the guard up, and
## the cleave goes into the hooked foe as he reaches them. Owned by JuggernautKit.

const GOLD := Color("ffc94a")          # the guard's glow and the cleave's outer edge (the source's is red)
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
	k.vfx("guard_tell")

## E on a held chain, planted in the guard or the cleave. In the guard the pull goes now; the cleave's own moment
## takes it as the cleave lands.
func pull_through() -> void:
	if guarding():
		k.warchain.pull()
		k.play("jug_guard")
	else:
		st["pull_next"] = true

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
	var chain := k.warchain
	if chain.pulling():
		aim = chain.to_anchor()      # hauled in: the strip looks down the chain
	if aim.length() > 0.1:
		st["dir"] = aim.normalized()
	var gk := clampf(float(st["t"]) / float(d["guard"]), 0.0, 1.0)
	AimKit.lane(h, "ult", {"dir": st["dir"], "len": float(d["len"]), "width": float(d["width"]), "fill": gk,
			"col": LANE_COL, "col2": GOLD, "all": true, "alpha": 1.3})
	HeroVfx.of(k.m).hold(h, "guard", gk)
	# a hooked foe coming up in the pull is struck in reach, however long the guard has run; the guard holds until
	# then, so the cleave doesn't go off in the air short of them
	var hauled: bool = chain.pulling() and chain.target != null
	if hauled and chain.to_anchor().length() <= float(d["len"]) * 0.8:
		_strike(d)
	elif not hauled and float(st["t"]) >= float(d["guard"]):
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
	if not k.warchain.pulling():         # (the pull is his lunge)
		k.travel(float(d["lunge"]), float(d["strike_t"]), {"invuln": 0.0, "trail": "dust", "dir": dir})
	k.vfx("riposte_go", h.pos, dir, {"len": float(d["lunge"])})

## The cleave lands: everyone in the strip (from where the guard stood) is hit once.
func _land(d: Dictionary) -> void:
	var h := k.h
	var dir: Vector2 = st["dir"]
	var pulled: bool = k.warchain.pulling()
	var from: Vector3 = h.pos if pulled else st["from"]
	st["phase"] = "recover"
	st["t"] = 0.0
	if not pulled:
		h.roll_t = 0.0
	var blocks := int(st["blocks"])
	var dmg := float(d["dmg"]) * (1.0 + float(d["block_k"]) * float(blocks)) * k.power("x")
	k.vfx("riposte_land", from, dir, {"len": float(d["len"]), "w": float(d["width"])})
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
		if HeroUlt.landed(k, f) in ["knock", "kill"]:
			_reset()
	if last_dealt > 0.0:
		strikes += 1
		var hp0 := h.hp
		h.heal(last_dealt * float(d["heal"]))
		last_healed = h.hp - hp0
		if last_healed >= 1.0:
			k.vfx("riposte_heal")
	if st.get("pull_next", false) and k.warchain.hooked():
		k.warchain.pull()

## On someone hit: the gold impact cloud, the hit-stop and a heavy shake.
func _impact(f: Ent, dir: Vector2, dealt: float) -> void:
	var h := k.h
	k.vfx("riposte_hit", f.pos, dir)
	Feel.hitstop(k.m, h, f, dealt, {"melee": true, "payoff": true, "heavy": true})
	Shake.incoming_big(k.m, f.pos, 0.6, h)

## A hunter who was up and went down to the cleave: it is ready again at once.
func _reset() -> void:
	resets += 1
	HeroUlt.reset(k)
	k.m.fx.word(k.h.pos + Vector3(0, 2.6, 0), "RIPOSTE READY", GOLD, true)
	ResetCue.play(k.h, "juggernaut_riposte_knock")

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
		k.vfx("guard_block", h.pos + Vector3(0, 1.2, 0) + to * 0.5, Vector2(to.x, to.z).normalized(),
				{"pitch": 0.08 * float(st["blocks"])})
		k.m.fx.word(h.pos + Vector3(0, 2.3, 0), "BLOCKED", GOLD, false)
	return true

## The gold shell over him while he guards (one node per hunter, shown and hidden).
func _show_glow(on: bool) -> void:
	if glow == null or not is_instance_valid(glow):
		if not on:
			return
		glow = _make_glow()
	glow.visible = on

func _make_glow() -> Node3D:
	var n := HeroVfx.of(k.m).shell(k.h, "guard_shell")
	k.self_nodes.append(n)
	return n
