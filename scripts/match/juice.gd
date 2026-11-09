class_name Juice
extends RefCounted
## How hits, shots, knocks and kills look and sound (the "oomph" layer). Gameplay never reads
## anything here: it only draws effects and plays sounds for what already happened.
##
## Hitstop and per-hit camera shake by tier belong to the Feel module (docs/DASHES_AND_ABILITY_FEEL.md
## §5.4-5.5); the big moments here (knock, kill, armor break) use the same amounts as its table
## (knock: 0.35 trauma for the one who did it, tier 4 freeze 0.07s) so the two read as one system.
##
## Everything random here uses the effects' own random stream (Fx.rng), never the match's or the
## global one, so a seeded match plays out exactly the same with or without these effects.

const HIT_COL := Color("fff0d2")
const HURT_COL := Color("ff7a5c")       # hits on you read hotter
const FAR := 24.0                       # beyond this from the player nothing is drawn for a hit

## Where on the target a hit from `by` lands (its near side, about chest high) and which way the
## sparks fly (on through it).
static func _hit_point(target: Ent, by: Ent, o: Dictionary) -> Array:
	var dir := Vector3.ZERO
	if by != null and is_instance_valid(by) and by != target:
		dir = target.pos - by.pos
	elif o.get("kb", null) is Vector2:
		var kb: Vector2 = o["kb"]
		dir = Vector3(kb.x, 0, kb.y)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var rad := float(target.get("r")) if target.get("r") != null else 0.4
	var hgt := 0.95 if target is Hunter else clampf(0.35 + rad, 0.5, 1.6)
	var y := (target as Hunter).hit_y() if target is Hunter else target.pos.y
	var at := Vector3(target.pos.x, y + hgt, target.pos.z) - dir * rad * 0.8
	return [at, dir]

static func _credit(by: Ent) -> Ent:
	if by is Kin and (by as Kin).owner_h:
		return (by as Kin).owner_h
	return by

## Every hit that lands (Match.on_damage): an impact flash at the point it struck, sparks out the
## far side, more of everything the harder it hit; crits flash gold, armor sheds blue shards. Hits
## that involve you are full size, other fights nearby are smaller, far ones draw nothing.
static func hit(m: Match, target: Ent, by: Ent, d: float, o: Dictionary, crit: bool, armor: bool) -> void:
	if m == null or m.fx == null or target == null:
		return
	var src := String(o.get("src", ""))
	var p: Hunter = m.player
	if p != null and p.flat_dist(target) > FAR:
		return
	var hp := _hit_point(target, by, o)
	var at: Vector3 = hp[0]
	var dir: Vector3 = hp[1]
	if src in ["burn", "heat", "fall"] or o.get("tick", false):
		# damage over time: a small ember, no flash
		m.fx.burst(at, Color("ff9a4a") if src == "burn" else HIT_COL, 3, 2.0, 0.3, -1.0, 0.7)
		return
	var credit := _credit(by)
	var mine := credit == p or target == p
	var power := clampf(d / 14.0, 0.35, 3.0)
	if not mine:
		power *= 0.65
	var col := HURT_COL if target == p else HIT_COL
	var ability := o.has("ab") and src != "kin"
	if ability: power = maxf(power, 1.3)       # an ability hit always lands big
	m.fx.impact(at, dir, col, power, crit, armor)
	# the body flinches along the hit (Ent.flinch: drawn only, springs back); big things barely move
	var heft := maxf(1.0, float(target.get("r")) * 1.6) if target.get("r") != null else 1.0
	target.flinch = (target.flinch + dir * (0.05 + 0.045 * power) * (1.4 if crit else 1.0) / heft).limit_length(0.3)
	if ability:
		AbilityFx.hit(m, target, by, d, o)
	# sound layers on top of the hit tick Match plays: armor rings, heavy hits thud, blades bite
	if credit == p and target != p:
		var melee: bool = by is Hunter and bool((by as Hunter).wpn.get("melee", false))
		if melee:
			m.sfx("slash_hit", target.pos, -5.0 if d >= 20.0 else -8.0)
		if armor:
			m.sfx("armor_hit", target.pos, -9.0)
		if d >= 28.0 and not melee:
			m.sfx("hit_heavy", target.pos, -7.0)
	elif target == p and armor:
		m.sfx("armor_hit", null, -12.0, 0.85)

## A gun going off (Hunter._emit_shot): the muzzle flash and embers, sized by how hard the round
## hits (a shotgun's whole volley, a sniper slug), for any gun the player can see.
static func shot(h: Hunter, start: Vector3, dir2: Vector2) -> void:
	var m: Match = h.m
	if m == null or m.fx == null or h.unseen:
		return
	var p: Hunter = m.player
	if p != null and p != h and p.flat_dist(h) > FAR:
		return
	var w: Dictionary = h.wpn
	var dmg := float(w.get("dmg", 10.0)) * float(maxi(1, int(w.get("pellets", 1))))
	var power := clampf(dmg / 16.0, 0.7, 3.0)
	var col: Color = w.get("color", Color("ffd9a0"))
	m.fx.muzzle(start + Vector3(dir2.x, 0, dir2.y) * 0.25, dir2, col, power)

## Someone knocked down (Match.knock): a burst of their team colour, a shockwave on the ground and a
## white flash, so the moment reads from anywhere on screen.
static func knock(m: Match, h: Hunter, credit: Ent) -> void:
	if m == null or m.fx == null:
		return
	var tc: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	var c := h.pos + Vector3(0, 0.9, 0)
	m.fx.flash(c, Color(1.0, 0.95, 0.85), 1.1, 0.16)
	m.fx.spark(c, Vector3.UP, tc.lerp(Color.WHITE, 0.35), 22, 11.0, 75.0, 0.4, 14.0, 1.5)
	m.fx.ring(h.pos, 3.4, Color(tc, 0.9), 0.4)
	m.fx.ring(h.pos, 1.8, Color(1, 1, 1, 0.8), 0.25)
	m.fx.dust(h.pos, 14)
	HeroVfx.of(m).play(h, "downed", h.pos, h.aim_dir())
	if credit == m.player and h != m.player:
		m.sfx("knock_confirm", null, -6.0)
		KnockCallout.say(m, "knock", h)

## Someone taken out for good (Match.eliminate): their light goes up in a column of sparks.
static func kill(m: Match, h: Hunter, credit: Ent) -> void:
	if m == null or m.fx == null:
		return
	var tc: Color = Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	var c := h.pos + Vector3(0, 0.6, 0)
	m.fx.spark(c, Vector3.UP, tc.lerp(Color.WHITE, 0.5), 26, 14.0, 14.0, 0.7, -2.0, 1.6)
	m.fx.burst(c, Color(tc, 0.8), 18, 3.0, 0.9, -4.0, 1.4)
	m.fx.ring(h.pos, 2.6, Color(tc, 0.85), 0.5)
	if credit == m.player and h != m.player:
		m.sfx("kill", null, -3.0)
		KnockCallout.say(m, "out", h)
		if m.hud: m.hud.flash(Color(tc, 1.0), 0.14)

## Armor broken (Match.on_armor_break): a burst of blue shards and a glassy crack, and a short
## freeze for whoever broke it (Feel tier 3: 0.045s).
static func armor_break(m: Match, h: Hunter, credit: Ent) -> void:
	if m == null or m.fx == null:
		return
	var c := Vector3(h.pos.x, h.hit_y() + 1.0, h.pos.z)
	m.fx.flash(c, Color("9ad8ff"), 0.8, 0.14)
	m.fx.spark(c, Vector3.UP, Color("b8e6ff"), 20, 9.0, 100.0, 0.35, 16.0, 1.2)
	m.sfx("armor_break", h.pos, -1.0)
	if credit == m.player and h != m.player:
		m.freeze_frame(0.045)

## A monster dying (Match.on_mob_dead): a flash and a spray in its colour, a ring for the big ones.
static func mob_dead(m: Match, mb: Mob, credit: Ent, big: bool) -> void:
	if m == null or m.fx == null:
		return
	if bool(mb.md.get("boss", false)):
		boss_dead(m, mb, credit)
		return
	var p: Hunter = m.player
	if p != null and p.flat_dist(mb) > FAR:
		return
	var col: Color = mb.md.get("color", Color.WHITE)
	var c := mb.pos + Vector3(0, 0.6 + float(mb.r) * 0.5, 0)
	m.fx.flash(c, col.lerp(Color.WHITE, 0.5), 0.6 if not big else 1.1, 0.12 if not big else 0.18)
	m.fx.spark(c, Vector3.UP, col.lerp(Color.WHITE, 0.3), 12 if not big else 22, 8.0 if not big else 11.0, 80.0, 0.3, 14.0, 1.0 if not big else 1.4)
	if big:
		m.fx.ring(mb.pos, 3.0, Color(col, 0.85), 0.4)
		m.fx.dust(mb.pos, 12)
		if credit == p:
			m.freeze_frame(0.05)

## A boss going down: the biggest moment in a match short of extracting. A white-hot flash, two
## shockwaves, a fountain of sparks in its colour, a beat of slow motion and the music dipping.
static func boss_dead(m: Match, b: Mob, credit: Ent) -> void:
	if m == null or m.fx == null:
		return
	var col: Color = b.md.get("color", Color("ffb070"))
	var c := b.pos + Vector3(0, 1.4, 0)
	m.fx.flash(c, Color(1, 0.96, 0.88), 2.4, 0.3)
	m.fx.spark(c, Vector3.UP, col.lerp(Color.WHITE, 0.35), 40, 15.0, 70.0, 0.7, 12.0, 2.0)
	m.fx.spark(c, Vector3.UP, Color(1, 0.95, 0.8), 24, 9.0, 180.0, 0.5, 6.0, 1.4)
	m.fx.ring(b.pos, 7.5, Color(col, 0.9), 0.6)
	m.fx.ring(b.pos, 4.0, Color(1, 1, 1, 0.85), 0.35)
	m.fx.dust(b.pos, 24)
	m.sfx("boom", b.pos, 3.0, 0.7)
	var p: Hunter = m.player
	if p != null and p.flat_dist(b) < 22.0:
		Sfx.duck(1.2)
		if m.hud: m.hud.flash(Color(1, 0.95, 0.85), 0.3)
		if credit == p or (credit is Hunter and (credit as Hunter).team == p.team):
			m.sfx("kill", null, -2.0, 0.85)
			m._slow(0.55, 0.3)

## A boss growing furious (Lairs.on_boss_phase): a flash and a ring of sparks off its body.
static func boss_phase(m: Match, b: Mob) -> void:
	if m == null or m.fx == null:
		return
	var col: Color = b.md.get("color", Color("ffb070"))
	var c := b.pos + Vector3(0, 1.6, 0)
	m.fx.flash(c, col.lerp(Color.WHITE, 0.4), 1.8, 0.22)
	m.fx.spark(c, Vector3.UP, col.lerp(Color.WHITE, 0.2), 30, 12.0, 120.0, 0.5, 10.0, 1.6)
	var p: Hunter = m.player
	if p != null and p.flat_dist(b) < 20.0:
		if m.hud: m.hud.flash(col, 0.18)

## Getting out (Match._extract): a column of light where they stood. For you, the screen whites out
## a little and a rising chord plays over the portal.
static func extract(m: Match, h: Hunter, col: Color) -> void:
	if m == null or m.fx == null:
		return
	var c := h.pos + Vector3(0, 0.4, 0)
	m.fx.spark(c, Vector3.UP, col.lerp(Color.WHITE, 0.5), 36, 18.0, 10.0, 0.8, -6.0, 1.8)
	m.fx.spark(c + Vector3(0, 1.0, 0), Vector3.UP, Color(1, 1, 1), 16, 10.0, 25.0, 0.6, -3.0, 1.2)
	m.fx.flash(c + Vector3(0, 0.8, 0), col.lerp(Color.WHITE, 0.6), 1.6, 0.3)
	m.fx.ring(h.pos, 3.2, Color(col, 0.9), 0.5)
	if h == m.player:
		m.sfx("extract_ok", null, -3.0)
		Sfx.duck(1.6)
		if m.hud: m.hud.flash(col.lerp(Color.WHITE, 0.6), 0.3)

## A footstep while running (Hunter render, with its dust puff): what it sounds like depends on
## what's underfoot (planks, paved paths and stairs, snow, or grass and earth). Only for people
## close to you, quieter for everyone else, silent while sneaking.
static func footstep(h: Hunter) -> void:
	var m: Match = h.m
	if m == null or m.world == null or h.unseen or h.crouch:
		return
	var p: Hunter = m.player
	if p != null and h != p and p.flat_dist(h) > 14.0:
		return
	var w: World = m.world
	var ix := int(floorf(h.pos.x)); var iz := int(floorf(h.pos.z))
	if not w.inb(ix, iz):
		return
	var i := w.idx(ix, iz)
	var surf := "grass"
	if w.bridge.has(i): surf = "wood"
	elif w.stairs.has(i) or w.paint.has(i) or w.kind[i] != World.T_GROUND: surf = "stone"
	elif w.style_at(i) == "frost": surf = "snow"
	Sfx.play(HeroSfx.of(h, "step_" + surf, "step_" + surf), h.pos, -13.0 if h == p else -17.0, 0.08)
