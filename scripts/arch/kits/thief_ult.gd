class_name ThiefUlt
extends RefCounted
## Dancer's ultimate on X, Encore (her "r" data in content/archetypes/thief.json; the source's Death Blossom,
## briefs/hero-ref/dancer.md "Ultimate (on X)"). A violet ring grows out from her over 0.4s (the short delay),
## then rides with her for 2s while a blade flies from her at every foe inside it every 0.4s (up to 5 each).
## Blades from the outer band of the ring (past 75% of its radius) hit harder and blight (healing barely
## takes) for 6s. She keeps moving, shooting and dashing; the cast gives her Vault back, and every blade
## refreshes her Marks. Landing blades on a rival hunter fills the bond meter once per cast, for the best of
## it (a hit, a knock or a kill; ArchKit.ult_bond), never the cast alone. Owned by ThiefKit (cast_ult, _tick,
## _drop_holds).

const RING_COL := Color("c9a0ff")      # the ring and the blades: her violet (the source's is cyan)
const RIM_COL := Color("ffd25a")       # the outer band, where blades hit harder
const BLADE_TIP := Color("fff2c0")
const HIT_COL := Color("e070ff")       # the flash a blade leaves on what it hits: her violet, run hot
const BLADE_SPEED := 30.0              # m/s: the cosmetic blade's flight (the hit lands when it arrives)
const ORBITERS := 3                    # blades circling her while it runs
const ORBIT_R := 0.9                   # m
const BOND_RANK := {"": 0, "hit": 1, "knock": 2, "kill": 3}

var k: ThiefKit
var st := {}                           # running: {t, next, n, bond, hits: {foe id: blades landed}}
var casts := 0                         # (tests, demo)
var blades := 0                        # blades landed
var rim_blades := 0                    # of which from the outer band
var bond_kind := ""                    # what the last cast paid the bond for ("" for nothing)

func _init(kit: ThiefKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.r_def()

func running() -> bool:
	return not st.is_empty()

## 0..1 of the cast left (the HUD's ring round the X slot).
func left_k() -> float:
	if st.is_empty():
		return 0.0
	var total := float(data()["grow"]) + float(data()["time"])
	return clampf(1.0 - float(st["t"]) / total, 0.0, 1.0)

## The ring's radius now: it grows from r0 to reach over `grow`, then holds.
func radius() -> float:
	var d := data()
	var gk := clampf(float(st.get("t", 0.0)) / float(d["grow"]), 0.0, 1.0)
	return lerpf(float(d["r0"]), float(d["reach"]), 1.0 - pow(1.0 - gk, 2.0))

## X pressed: the ring starts growing (a ring with nobody in it still runs).
func start() -> void:
	var d := data()
	casts += 1
	bond_kind = ""
	st = {"t": 0.0, "next": float(d["grow"]), "n": int(d["shots"]), "hits": {}, "best": ""}
	var h := k.h
	k.play("thf_encore")
	k.m.fx.word(h.pos + Vector3(0, 3.6, 0), String(d["name"]).to_upper(), RING_COL, true)
	k.m.sfx("dj_encore", h.pos, -2.0 if h.is_local() else -5.0, 1.0)
	k.m.later(float(d["grow"]), func(): if running(): k.m.sfx("dj_encore_whirr", h.pos, -6.0, 1.0))
	k.net_ring(h.pos, float(d["reach"]), RING_COL)
	h.dashes = h.max_dashes()             # the source's info card: it resets the cartwheel
	DashReset.cue(h)

## The cast ends (its time ran out, a merge, a knock): nothing more flies, and the bond is paid for the best
## thing its blades did to a rival hunter.
func drop() -> void:
	if not st.is_empty() and String(st["best"]) != "":
		bond_kind = String(st["best"])
		k.ult_bond(bond_kind)
	st = {}
	AimKit.hide(k.h, "ult")
	AimKit.hide(k.h, "ult_rim")

func tick(dt: float) -> void:
	if st.is_empty():
		return
	var d := data()
	var h := k.h
	if h.downed or h.out:
		drop()
		return
	st["t"] = float(st["t"]) + dt
	_draw_ring(d)
	_orbit(d)
	if float(st["t"]) >= float(st["next"]) and int(st["n"]) > 0:
		st["n"] = int(st["n"]) - 1
		st["next"] = float(st["next"]) + float(d["time"]) / float(d["shots"])
		_volley(d)
	if int(st["n"]) <= 0 and float(st["t"]) >= float(d["grow"]) + float(d["time"]):
		drop()                             # a plain fade: no final burst

## The ring everyone sees: it grows out from her, then rides with her; a dashed line marks the outer band.
func _draw_ring(d: Dictionary) -> void:
	var gk := clampf(float(st["t"]) / float(d["grow"]), 0.0, 1.0)
	var r := radius()
	AimKit.circle(k.h, "ult", {"self": true, "r": r, "col": RING_COL, "col2": RIM_COL, "all": true, "ticks": true,
			"fill": 0.3 * gk, "alpha": 1.2})
	AimKit.circle(k.h, "ult_rim", {"self": true, "r": r * float(d["rim"]), "col": Color(RIM_COL, 0.7), "all": true,
			"dashed": true, "alpha": 0.7})

## The blades circling her while it runs (pooled looks, placed every step).
func _orbit(d: Dictionary) -> void:
	var h := k.h
	var a0 := float(st["t"]) * 7.0
	for i in ORBITERS:
		var a := a0 + TAU * float(i) / float(ORBITERS)
		var at := h.pos + Vector3(cos(a) * ORBIT_R, 1.1 + 0.15 * sin(a * 2.0), sin(a) * ORBIT_R)
		var vel := Vector2(-sin(a), cos(a)) * 6.0
		k.fx().place("enc_orb%d" % i, "blade", at, vel, RING_COL, BLADE_TIP, 0.5, 0.18)
	if float(st["t"]) >= float(d["grow"]) + float(d["time"]) - 0.05:
		for i in ORBITERS:
			k.fx().unplace("enc_orb%d" % i)

## One blade at every foe inside the ring (each at most `shots` times), and the spin-throw pose.
func _volley(d: Dictionary) -> void:
	var h := k.h
	var r := radius()
	var thrown := false
	for f in k.foes_in(h.pos, r):
		if f is Kin or not k.sees(f):
			continue
		var key: int = f.get_instance_id()
		var got := int((st["hits"] as Dictionary).get(key, 0))
		if got >= int(d["shots"]):
			continue
		st["hits"][key] = got + 1
		var rim := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z).length() > r * float(d["rim"])
		_blade(f, rim)
		thrown = true
	if thrown:
		k.play("thf_encore_throw_l" if int(st["n"]) % 2 == 0 else "thf_encore_throw_r")
		k.m.sfx("dj_blade", h.pos, -6.0, randf_range(0.95, 1.1))

## A cosmetic blade flies from her hand; the hit lands when it arrives.
func _blade(f: Ent, rim: bool) -> void:
	var h := k.h
	var from := h.pos + Vector3(0, 1.1, 0)
	var to := f.pos + Vector3(0, 1.0, 0)
	var dv := Vector2(to.x - from.x, to.z - from.z)
	var dist := dv.length()
	var n0: int = k.m.shots.size()
	k.m.spawn_shot(h, from, dv.normalized() * BLADE_SPEED, 0.0, dist / BLADE_SPEED, 0.08, RING_COL, {"cos": true})
	if k.m.shots.size() > n0:
		k.fx().ride(k.m.shots[-1], "blade", RIM_COL if rim else RING_COL, HIT_COL, 0.9, 0.22)
	k.m.later(dist / BLADE_SPEED, func(): _hit(f, rim))

## A blade arrives: its damage (more from the outer band, which also blights), a red flash, Marks refreshed,
## and the bond for a rival hunter.
func _hit(f: Ent, rim: bool) -> void:
	var h := k.h
	if not is_instance_valid(h) or not is_instance_valid(f) or f.dead or not f.hittable():
		return
	var d := data()
	var dmg := float(d["dmg"]) + (float(d["rim_dmg"]) if rim else 0.0)
	var o := {"src": "abil", "ab": "ult", "tags": ["encore"], "crit": rim}
	if rim:
		o["blight"] = float(d["rim_blight"])
	var was_blighted := f.blight_t > 0.0
	var dealt := f.hurt(dmg * k.power("ult"), h, o)
	if dealt <= 0.0:
		return
	blades += 1
	if rim:
		rim_blades += 1
		k.fx().puff(f.pos + Vector3(0, 1.0, 0), RIM_COL, 0.8, 0.3, HIT_COL)
		if not was_blighted:
			# once, as the blight lands (above the damage numbers, so they don't overprint)
			k.m.fx.word(f.pos + Vector3(0, 3.0, 0), "BLIGHT", Color("b08aff"), false)
	k.fx().star(f.pos + Vector3(0, 1.0, 0), HIT_COL, 0.8 if rim else 0.55, 0.16)
	k.m.sfx("dj_encore_hit", f.pos, -8.0, randf_range(0.9, 1.15) * (0.85 if rim else 1.0))
	k.refresh_marks()
	if f is Hunter and f.team != h.team and not st.is_empty():
		var kind := ThiefUlt.landed_kind(f as Hunter)
		if int(BOND_RANK[kind]) > int(BOND_RANK[String(st["best"])]):
			st["best"] = kind

## What landing on a rival hunter counts as for the bond: a kill (out), a knock (down) or a hit.
static func landed_kind(t: Hunter) -> String:
	if t.out or t.dead:
		return "kill"
	return "knock" if t.downed or t.hp <= 0.0 else "hit"
