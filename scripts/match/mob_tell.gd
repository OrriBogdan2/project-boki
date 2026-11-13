class_name MobTell
extends RefCounted
## What a mob's attack looks like before it lands, and where it lands (docs/MOB_TELLS.md).
## `shapes` is the one source for both: Mob draws it as a ground telegraph (the Hunters' Fx
## telegraph, filling to the hit frame) and hit-tests with it, so the tell is the real reach.
## Each shape is already grown by the radius of the one being attacked (`pad`):
##   lane   {lane: true, from: Vector3, dir: Vector2, len: float, width: float}
##   circle {lane: false, at: Vector3, r: float}

const REF_R := 0.4  # m, a hunter's body radius when the tell is drawn for nobody in particular
const LUNGE_SPEED := 12.0  # m/s the skitter dashes at
const LUNGE_T := 0.2  # s the dash runs
const MUZZLE := 0.6  # m ahead of the mob where a bolt starts
const SPIT := {"speed": 8.5, "life": 1.0, "size": 0.32}  # m/s, s, m (bolt radius)
const VOLLEY := {"speed": 9.5, "life": 10.5 / 9.5, "size": 0.28, "fan": [-0.2, 0.0, 0.2]}  # fan: radians off the aim
const SLAM_FWD := 0.9  # m ahead of a slamming mob where the blow lands
const SLAM_R := 2.3  # m, a slam's default radius (md "slam_r" overrides)
const LINGER := 0.15  # s the filled tell stays up after the hit frame
const GLOW_MAX := 0.55  # body glow at the hit frame (the flash mix, 0..1)
const HIT_DY := {"lunge": 1.2, "slam": 1.5, "fuse": 1.6}  # m of height a blow still reaches
const TELL_COL := {
	"lunge": Color("ff6a4a"),
	"spit": Color("ffb04a"),
	"slam": Color("ff4a3a"),
	"fuse": Color("ff8a2a"),
	"volley": Color("6ad8ff"),
}


## The reach of this mob's attack for a target of radius `pad`: [] for a mob that does not attack.
static func shapes(mb: Mob, pad: float) -> Array:
	var d := mb.atk_dir
	var o := mb.pos if mb.st == "windup" else mb.atk_at
	match String(mb.md["attack"]):
		"lunge":
			# the body swept along the dash
			return [_lane(o, d, -mb.r, LUNGE_SPEED * LUNGE_T + 2.0 * mb.r, 2.0 * mb.r, pad)]
		"spit":
			return [_bolt(o, d, SPIT, pad)]
		"volley":
			var out: Array = []
			for a in VOLLEY["fan"]:
				out.append(_bolt(o, d.rotated(a), VOLLEY, pad))
			return out
		"slam", "fuse":
			return [{"lane": false, "at": mb.atk_at, "r": float(mb.md.get("slam_r", SLAM_R)) + pad}]
	return []


## A lane from `start` m ahead of `o`, `len` long, `width` wide, grown by `pad` all round.
static func _lane(o: Vector3, d: Vector2, start: float, length: float, width: float, pad: float) -> Dictionary:
	var from := o + Vector3(d.x, 0.0, d.y) * (start - pad)
	return {"lane": true, "from": from, "dir": d, "len": length + 2.0 * pad, "width": width + 2.0 * pad}


## The path of a bolt: it hits what comes within its radius (and the hit slack) of its centre, so the
## lane is its centre line grown by that much on every side, the far end too. A shot flies whole
## Match.DT steps until its life is spent, so it can go up to one step past speed * life.
static func _bolt(o: Vector3, d: Vector2, bolt: Dictionary, pad: float) -> Dictionary:
	var steps := ceili(float(bolt["life"]) / Match.DT - 1e-4)
	var reach := float(bolt["speed"]) * Match.DT * steps
	var rim := float(bolt["size"]) + Match.HIT_SLACK
	return _lane(o, d, MUZZLE - rim, reach + 2.0 * rim, 2.0 * rim, pad)


static func contains(sh: Dictionary, p: Vector3) -> bool:
	if sh["lane"]:
		return AimMode.in_lane(sh["from"], sh["dir"], sh["len"], sh["width"], p)
	return AimMode.in_circle(sh["at"], sh["r"], p)


## Does the blow (a lunge, slam or burst) reach `e` right now?
static func hits(mb: Mob, e: Ent) -> bool:
	if absf(e.pos.y - mb.pos.y) >= float(HIT_DY[mb.md["attack"]]):
		return false
	for sh in shapes(mb, e.r):
		if contains(sh, e.pos):
			return true
	return false


## The mob goes where it aims: where a slam or burst will land, and the radius it draws for.
static func begin(mb: Mob) -> void:
	mb.atk_pad = mb.tgt.r if mb.tgt else REF_R
	mb.atk_at = mb.pos
	if mb.md["attack"] == "slam":
		mb.atk_at += Vector3(mb.atk_dir.x, 0.0, mb.atk_dir.y) * SLAM_FWD


## Each step of a wind-up: draw the tell, aimed attacks following the aim, filled to the hit frame.
static func update(mb: Mob) -> void:
	var sh := shapes(mb, mb.atk_pad)
	var fx = mb.m.fx
	if mb.tele.is_empty():
		var col := Feel.hostile(TELL_COL[mb.md["attack"]])
		for s in sh:
			if s["lane"]:
				mb.tele.append(fx.telegraph_rect(s["from"], s["dir"], s["len"], s["width"], col))
			else:
				mb.tele.append(fx.telegraph_circle(s["at"], s["r"], col))
	for i in sh.size():
		if sh[i]["lane"]:
			fx.aim_telegraph(mb.tele[i], sh[i]["from"], sh[i]["dir"])
		fx.telegraph_progress(mb.tele[i], 1.0 - mb.st_t / float(mb.md["windup"]))


## After the hit frame the full tell stays up a moment, then goes.
static func linger(mb: Mob, dt: float) -> void:
	if mb.tele.is_empty() or mb.st == "windup":
		return
	mb.tele_t -= dt
	if mb.tele_t <= 0.0:
		clear(mb)


static func clear(mb: Mob) -> void:
	for n in mb.tele:
		mb.m.fx.end_telegraph(n)
	mb.tele.clear()


## The body brightens in the attack's colour as the blow nears, to its peak on the hit frame.
static func glow(mb: Mob, wind: float) -> void:
	if mb.flash_t > 0.0:
		return  # a hit's own white flash owns the body
	var on := mb.st == "windup" and TELL_COL.has(mb.md["attack"])
	if not on and not mb.glowing:
		return
	mb.glowing = on
	mb._flash_set = -1.0  # Ent.render sets the flash again when it next changes
	var col: Color = Feel.hostile(TELL_COL[mb.md["attack"]]) if on else Color.WHITE
	for mt in mb.mats:
		mt.set_shader_parameter("flash_color", col)
		mt.set_shader_parameter("flash", GLOW_MAX * clampf(wind, 0.0, 1.0) if on else 0.0)
