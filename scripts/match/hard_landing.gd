class_name HardLanding
extends RefCounted
## A Hard Landing (decision 0050): on the opening drop, the dive key held to the ground keeps the canopy
## shut (DropFeel.holds_shut) and the Hunter hits at dive speed. Every monster in `radius` is staggered and
## hurt, the lander is slowed and cannot attack for a moment, and everyone near hears it. The numbers are
## the "hard_landing" block of content/rules/drop.json.

const NET_EVENT := "hland"                  # the landing, sent to the other clients for its ring and sound
const LOCKED_KEYS := ["fire", "sec", "sec_hold", "sig", "skill", "ult", "throw", "kin_ab", "gear1", "gear2"]
const CRACK_COLORS := [Color("8a7a66"), Color("2a241e")]      # the cracked ground: dry earth, dark seams

## Read through DropFeel on every use: DropFeel loads this script, so a copy taken at load would be empty.
static var rules: Dictionary:
	get: return DropFeel.rules("hard_landing")
static var radius: float:
	get: return rules["radius"]

## The landing on its owner's game: the hit, the lander's lock, the local camera, then the show for all.
static func land(m: Match, h: Hunter) -> void:
	for mb: Mob in m.mobs.duplicate():
		if hits(h, mb):
			mb.hurt(rules["damage"], h, {"stun": rules["stun_s"], "src": "hard_landing"})
	h.land_t = rules["lock_s"]
	h.add_slow(float(rules["lock_s"]), float(rules["slow_k"]))
	h.squash = rules["squash"]
	if h == m.player and h.ctrl == "local":
		m.cam.dip(rules["dip_m"], rules["dip_s"])
		m.freeze_frame(rules["hitstop_s"])
	show(m, h, h.pos)
	m.net_event([NET_EVENT, h.nid, h.pos.x, h.pos.y, h.pos.z])

## Another client's landing: [NET_EVENT, lander id, x, y, z].
static func on_net(m: Match, x: Array) -> void:
	show(m, m.ents_by_id.get(String(x[1]), null) as Hunter, Vector3(x[2], x[3], x[4]))

## Camp and Blight monsters inside the ring; never a lair boss (Hunters and Boki are not in Match.mobs).
static func hits(h: Hunter, mb: Mob) -> bool:
	return not mb.dead and not mb is Boss and mb.team != h.team and h.flat_dist(mb) <= radius

## On every client: the ring at the effect's radius in the lander's team colour, dust, debris, a crack in
## the ground, and the boom, which pings on a rival's minimap out to `hear_m`.
static func show(m: Match, h: Hunter, at: Vector3) -> void:
	if h == null:
		return
	m.fx.ring(at, radius, Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()], rules["ring_s"])
	m.fx.dust(at, int(rules["dust"]))
	m.brk.debris(at, rules["chunk_mat"], int(rules["chunks"]))
	LDFx.of(m).scorch(at, float(rules["crack_m"]) * 0.5, rules["crack_s"], CRACK_COLORS[0], CRACK_COLORS[1])
	m.sfx("hard_landing", at)
	m.note_sound(h, at, "boom", rules["hear_m"])

## While the lander's lock runs: no attack and no ability (moving, slowed, is still theirs).
static func gate(h: Hunter) -> void:
	if h.land_t <= 0.0:
		return
	for key: String in LOCKED_KEYS:
		h.inp[key] = false
