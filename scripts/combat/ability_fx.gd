class_name AbilityFx
extends RefCounted
## How abilities look and sound, keyed by how they're delivered (the tell) and by what they do (the
## impact category), so any ability gets the same language without its data naming a sound or an
## effect: a gun's right click (content/hunter_abilities), a Boki's ability, and the archetype kits (their
## Feel module can take its tell and impact rows from tell_row / impact_row). Presentation only:
## nothing in the simulation reads anything here.
##
## Categories and colours follow docs/DASHES_AND_ABILITY_FEEL.md §5.1 (damage, control, sustain,
## shield, utility); shake amounts follow §5.5 and stay inside the §5.7 budget for E/RMB-class
## abilities (own cast at most 0.15-0.25). Delivery names match the grammar's (projectile, cone,
## beam, burst, zone, trap, wall, aura, tether, leap, blink, summon, dash) plus a few the weapon
## kits use (rail, disc, reflect, launch, area).

const CAT := {
	"damage": Color("ff7a3d"), "control": Color("c46bff"), "sustain": Color("b8f06a"),
	"shield": Color("fff1b8"), "utility": Color("5fd8ff"),
}

## Layer 1, the tell: delivery -> [sound, dB, pitch].
const TELL := {
	"projectile": ["ab_throw", -4.0, 1.0], "rail": ["ab_rail", 0.0, 1.0], "beam": ["ab_rail", -3.0, 1.15],
	"cone": ["ab_blast", 0.0, 1.0], "burst": ["ab_blast", -3.0, 1.2], "area": ["ab_slam", -1.0, 1.0],
	"zone": ["ab_plant", -5.0, 0.8], "aura": ["ab_guard", -5.0, 0.8], "summon": ["ab_wall", -5.0, 1.2],
	"leap": ["ab_leap", -3.0, 1.0], "launch": ["ab_leap", -5.0, 1.25], "dash": ["ab_leap", -7.0, 1.4],
	"wall": ["ab_wall", -2.0, 1.0], "reflect": ["ab_guard", -2.0, 1.0], "trap": ["ab_plant", -3.0, 1.0],
	"tether": ["ab_tether", -3.0, 1.0], "blink": ["ab_blink", -3.0, 1.0], "disc": ["ab_whirr", -5.0, 1.0],
}
## Layer 3, the impact: category -> [sound, dB, pitch]. Control is a hard hit with a dazed ring.
const IMPACT := {
	"damage": ["ab_hit", -4.0, 1.0], "control": ["ab_stun", -3.0, 1.0], "sustain": ["heal", -6.0, 1.1],
	"shield": ["ab_shield_hit", -5.0, 1.0], "utility": ["ping", -9.0, 1.3],
}

const FAR := 26.0      # beyond this from the player, other people's casts draw and play nothing

static func tell_row(delivery: String) -> Array:
	return TELL.get(delivery, TELL["projectile"])

static func impact_row(cat: String) -> Array:
	return IMPACT.get(cat, IMPACT["damage"])

## The same rows in the archetype Feel module's [sound, pitch] shape (Feel.DELIVERY_TELL and
## Feel.CATEGORY_IMPACT can read these, so archetype kits sound like the weapon kits).
static func feel_tell(delivery: String) -> Array:
	var r := tell_row(delivery)
	return [r[0], r[2]]

static func feel_impact(cat: String) -> Array:
	var r := impact_row(cat)
	return [r[0], r[2]]

static func cat_color(cat: String) -> Color:
	return CAT.get(cat, Color("e8f4ff"))

## What a hit did, from its hit options: control (stun, root, lift, slow, pull) beats damage.
static func category(o: Dictionary) -> String:
	for k in ["stun", "root", "lift", "slow"]:
		if float(o.get(k, 0.0)) > 0.0:
			return "control"
	return "damage"

## Does the archetypes branch's Feel module run hitstop and shake for hits? Then this layer leaves
## per-hit shake to it (so the two never double up).
static var _feel := -1
static func feel_owns() -> bool:
	if _feel < 0:
		_feel = 1 if ResourceLoader.exists("res://scripts/arch/feel.gd") else 0
	return _feel == 1

static func _mine(m: Node, who: Node) -> bool:
	var p = m.get("player")
	return p != null and (who == p or (who is Kin and (who as Kin).owner_h == p))

## The cast's volume for the local player (§5.2/5.6): own casts as written, allies' 4 dB down,
## rivals' 3 dB up when they're close enough to reach you.
static func _vol(m: Node, caster: Node, at: Vector3) -> float:
	var p = m.get("player")
	if p == null or caster == null or _mine(m, caster):
		return 0.0
	if caster is Ent and int((caster as Ent).team) == int(p.team):
		return -4.0
	return 3.0 if Vector2(p.pos.x - at.x, p.pos.z - at.z).length() < 12.0 else -2.0

static func _far(m: Node, at: Vector3) -> bool:
	var p = m.get("player")
	return p != null and Vector2(p.pos.x - at.x, p.pos.z - at.z).length() > FAR

## A cast going off at `at` toward dir2: its tell sound, a flash at the hand, and an effect shaped by
## the delivery (a rail's bolt of light, a cone's blast fan, a wall's slam, a trap's spark, a blink's
## implosion). o: optional {range, radius}.
static func cast(m: Node, caster: Node, delivery: String, at: Vector3, dir2: Vector2, col: Color, o := {}) -> void:
	if m == null or m.get("fx") == null or caster == null or _far(m, at) or m.fx.own_look:
		return
	var fx: Fx = m.fx
	var mine := _mine(m, caster)
	var row := tell_row(delivery)
	# grammar casts (Boki, archetype kits): when the Feel module is in it plays their tell, pointed
	# at these rows (feel_tell); a Boki's auto cast sits a little under its partner's own casts
	if not (o.get("grammar", false) and feel_owns()):
		m.sfx(String(row[0]), at, float(row[1]) + _vol(m, caster, at) - (4.0 if caster is Kin else 0.0), float(row[2]))
	var d3 := Vector3(dir2.x, 0, dir2.y)
	var hand: Vector3 = at + Vector3(0, 1.0, 0) + d3 * 0.6
	var hot := col.lerp(Color.WHITE, 0.35)
	# every cast: a ring at the caster's feet in the ability's colour, so you see who cast it
	if not delivery in ["launch", "trap", "wall"]:
		fx.ring((caster as Ent).pos if caster is Ent else at, 1.25, Color(col, 0.85), 0.22)
	match delivery:
		"rail", "beam":
			var rng := float(o.get("range", 14.0))
			fx.beam(hand, hand + d3 * rng, col, 0.55, 0.32)
			fx.flash(hand, hot, 0.9, 0.12)
			fx.spark(hand, d3, hot, 14, 16.0, 14.0, 0.2, 0.0, 1.4)
			fx.ring(at, 1.6, Color(col, 0.9), 0.25)
		"cone", "burst":
			fx.flash(hand, hot, 1.2, 0.12)
			fx.spark(hand, d3 if delivery == "cone" else Vector3.UP, hot, 26, 15.0, 32.0 if delivery == "cone" else 150.0, 0.24, 2.0, 1.5)
			fx.burst(hand + d3 * 0.8, Color(0.85, 0.82, 0.78, 0.4), 10, 2.5, 0.6, -0.5, 2.0, d3 if delivery == "cone" else Vector3.UP, 25.0 if delivery == "cone" else 180.0)
			fx.ring(at + d3 * 1.2, float(o.get("radius", 4.0)) * 0.8, Color(col, 0.8), 0.25)
		"projectile", "disc":
			fx.flash(hand, hot, 0.65, 0.09)
			fx.spark(hand, d3, hot, 9, 10.0, 18.0, 0.16, 0.0, 1.1)
		"leap", "launch", "dash":
			fx.dust(at, 12)
			fx.ring(at, 1.8, Color(col, 0.8), 0.25)
			fx.spark(at + Vector3(0, 0.2, 0), Vector3.UP, hot, 10, 7.0, 60.0, 0.25, 10.0, 1.0)
		"wall", "summon":
			fx.flash(at + Vector3(0, 1.0, 0), hot, 1.0, 0.14)
			fx.spark(at + Vector3(0, 0.2, 0), Vector3.UP, hot, 16, 8.0, 70.0, 0.3, 8.0, 1.2)
			fx.ring(at, 2.0, Color(col, 0.85), 0.3)
			fx.dust(at, 10)
		"reflect", "aura":
			fx.flash(hand, hot, 0.9, 0.14)
			fx.ring(at, float(o.get("radius", 1.9)), Color(col, 0.95), 0.3)
			fx.ring(at, float(o.get("radius", 1.9)) * 0.6, Color(1, 1, 1, 0.7), 0.2)
			fx.spark(hand + Vector3(0, 0.3, 0), Vector3.UP, hot, 12, 6.0, 120.0, 0.25, 4.0, 1.0)
		"trap", "zone":
			fx.flash(at + Vector3(0, 0.3, 0), hot, 0.6, 0.12)
			fx.spark(at + Vector3(0, 0.1, 0), Vector3.UP, hot, 10, 5.0, 60.0, 0.22, 12.0, 0.9)
			fx.ring(at, float(o.get("radius", 1.1)), Color(col, 0.95), 0.35)
			fx.ring(at, float(o.get("radius", 1.1)) * 1.8, Color(col, 0.6), 0.45)
		"tether":
			fx.flash(at + Vector3(0, 1.0, 0), hot, 0.9, 0.12)
			fx.spark(at + Vector3(0, 1.0, 0), Vector3.UP, hot, 10, 6.0, 140.0, 0.22, 4.0, 1.0)
		"blink":
			fx.flash(at + Vector3(0, 0.9, 0), hot, 1.0, 0.14)
			fx.spark(at + Vector3(0, 0.9, 0), Vector3.UP, hot, 14, 8.0, 180.0, 0.25, 0.0, 1.0)
			fx.ring(at, 1.4, Color(col, 0.85), 0.22)

## An area landing (a slam, a mine going off, an ability's burst): a shockwave the size of what it
## covers, rubble and dust, and a shake that fades with distance (§5.5 leap landing / big area).
static func land(m: Node, caster: Node, at: Vector3, r: float, col: Color) -> void:
	if m == null or m.get("fx") == null or _far(m, at):
		return
	var fx: Fx = m.fx
	var hot := col.lerp(Color.WHITE, 0.4)
	fx.flash(at + Vector3(0, 0.5, 0), hot, 0.5 + r * 0.35, 0.16)
	fx.ring(at, r * 1.15, Color(col, 0.9), 0.32)
	fx.ring(at, r * 0.6, Color(1, 1, 1, 0.7), 0.2)
	fx.spark(at + Vector3(0, 0.2, 0), Vector3.UP, hot, int(10 + r * 6), 6.0 + r * 2.0, 65.0, 0.35, 14.0, 1.0 + r * 0.15)
	fx.dust(at, int(8 + r * 4))
	if r >= 1.5:
		m.sfx("ab_slam", at, (-2.0 if r > 2.0 else -5.0) + _vol(m, caster, at), clampf(1.25 - r * 0.08, 0.85, 1.2))
		if r >= 3.0 and caster is Ent and not _mine(m, caster):
			Shake.incoming_big(m, at, 0.5, caster as Ent)

## What an ability hit does to the one it hit, readable at a glance and by ear (Juice.hit calls this
## for every ability hit): the category's impact sound, then the status: a stun rings round their
## head, a root pins rings at their feet, a slow frosts them, a hard knock throws dust behind them.
static func hit(m: Match, target: Ent, by: Ent, d: float, o: Dictionary) -> void:
	var fx: Fx = m.fx
	var p: Hunter = m.player
	var credit: Ent = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else by
	var mine := credit == p or target == p
	var cat := category(o)
	if mine and not o.get("tick", false):
		var row := impact_row(cat)
		m.sfx(String(row[0]), target.pos, float(row[1]) - (0.0 if target == p else 2.0), float(row[2]))
	var head := target.pos + Vector3(0, 1.9 if target is Hunter else 1.3, 0)
	var stun := float(o.get("stun", 0.0)); var root := float(o.get("root", 0.0)); var slow := float(o.get("slow", 0.0))
	if stun > 0.0:
		fx.ring(head, 0.7, Color("fff27a"), 0.35)
		fx.spark(head, Vector3.UP, Color("fff6b0"), 10, 4.0, 180.0, 0.35, 0.0, 0.8)
		fx.word(head + Vector3(0, 0.3, 0), "STUNNED", Color("fff27a"), false)
	elif root > 0.0:
		fx.ring(target.pos, 1.0, Color("ffb04a"), 0.5)
		fx.ring(target.pos, 0.6, Color("ffb04a"), 0.6)
		fx.word(head + Vector3(0, 0.3, 0), "ROOTED", Color("ffb04a"), false)
	elif slow > 0.0:
		fx.burst(target.pos + Vector3(0, 0.8, 0), Color("bff0ff"), 10, 2.0, 0.5, -1.0, 1.0)
		fx.ring(target.pos, 0.9, Color("bff0ff", 0.8), 0.3)
		if mine: m.sfx("ab_slow", target.pos, -6.0)
	var kb: Vector2 = o.get("kb", Vector2.ZERO) if o.get("kb", null) is Vector2 else Vector2.ZERO
	if kb.length() >= 6.0 or float(o.get("lift", 0.0)) >= 4.0:
		var back := Vector3(kb.x, 0, kb.y).normalized() if kb.length() > 0.1 else Vector3.ZERO
		fx.dust(target.pos - back * 0.4, 10)
		fx.spark(target.pos + Vector3(0, 0.5, 0), back + Vector3(0, 0.6, 0), Color(0.9, 0.85, 0.75), 8, 6.0, 40.0, 0.3, 12.0, 0.9)
	# the shake for whoever landed it (§5.5: T2 0.08, T3 0.15); the victim's comes from Match
	if credit == p and target != p and not feel_owns():
		var t3 := stun > 0.0 or root > 0.0 or d >= 22.0 or kb.length() >= 8.0
		if t3 and stun > 0.0: m.freeze_frame(0.045)     # (Feel tier 3, target side)

## A held charge building (a charge-shot's hold): a glow gathering at the hand that grows and
## brightens, sparks drawn in, and a bright ping the moment it's full. k: 0..1.
static func charging(m: Match, h: Hunter, k: float, col: Color, was: float) -> void:
	if m == null or m.fx == null or _far(m, h.pos):
		return
	var d := h.aim_dir()
	var hand := h.pos + Vector3(d.x * 0.7, 1.0, d.y * 0.7)
	var hot := col.lerp(Color.WHITE, 0.3 + 0.4 * k)
	if int(was * 12.0) != int(k * 12.0) and k < 1.0:
		m.fx.flash(hand, hot, 0.25 + 0.45 * k, 0.09)
		m.fx.spark(hand + Vector3(0, 0.6, 0), Vector3.DOWN, hot, 3, 3.0 + 3.0 * k, 160.0, 0.14, 0.0, 0.7)
	if was < 1.0 and k >= 1.0:
		m.fx.flash(hand, Color.WHITE.lerp(col, 0.3), 1.0, 0.12)
		m.fx.ring(h.pos, 1.5, Color(col, 0.95), 0.22)
		m.sfx("ab_ready", h.pos, -4.0 if h == m.player else -10.0)

## A trail behind an ability's projectile in flight (Match render), so a right click reads from
## across the screen even among gunfire: a few hot motes every ~40ms.
static func trail(m: Match, s: Dictionary, at: Vector3) -> void:
	var t := float(s.get("trail_t", 0.0))
	var now := float(m.time)
	if now - t < 0.04 or _far(m, at):
		return
	s["trail_t"] = now
	var v: Vector2 = s["vel"]
	var back := Vector3(-v.x, 0, -v.y).normalized() if v.length() > 0.1 else Vector3.UP
	var col: Color = s["col"]
	m.fx.burst(at, col.lerp(Color.WHITE, 0.3), 3, 1.0, 0.28, 0.0, 1.2, back, 25.0)

## An ability's projectile ending without hitting anyone (out of range, into a wall): a pop of its
## colour and a soft fizz, so a miss reads as a miss rather than vanishing.
static func fizzle(m: Match, at: Vector3, col: Color) -> void:
	if m == null or m.fx == null or _far(m, at):
		return
	m.fx.flash(at, col.lerp(Color.WHITE, 0.4), 0.45, 0.08)
	m.fx.spark(at, Vector3.UP, col.lerp(Color.WHITE, 0.3), 6, 4.0, 160.0, 0.18, 6.0, 0.8)
	m.sfx("ab_shield_hit", at, -14.0, 0.7)

## A boomerang caught back in the hand: a bright snap and a little ring.
static func caught(m: Match, by: Node, col: Color) -> void:
	if m == null or m.fx == null or not (by is Ent) or _far(m, (by as Ent).pos):
		return
	var at := (by as Ent).pos + Vector3(0, 1.0, 0)
	m.fx.flash(at, col.lerp(Color.WHITE, 0.5), 0.5, 0.08)
	m.fx.ring((by as Ent).pos, 1.0, Color(col, 0.85), 0.18)
	m.sfx("ab_guard", at, -10.0 if by == m.player else -16.0, 1.3)
