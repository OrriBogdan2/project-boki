class_name ThiefUlt
extends RefCounted
## Sable's ultimate on X, Encore (her "x" data in content/archetypes/thief.json; the source's Death Blossom,
## briefs/hero-ref/dancer.md "Ultimate (on X)"). A violet ring grows out from her over 0.4s (the short delay),
## then rides with her for 2s while she dances (thf_encore_dance, upper body over her walking legs) and on every
## beat a blade leaves one hand or the other at every foe inside it (0.2s apart, up to 10 each), the ring pulsing.
## Blades from the outer band of the ring (past 75% of its radius) hit harder and blight (healing barely
## takes) for 6s. She keeps moving, shooting and dashing; the cast gives her Vault back, and every blade
## refreshes her Marks. A blade landing on a rival hunter fills the bond meter (HeroUlt.landed: the best of
## the cast counts, a hit, a knock or a kill), never the cast alone. Owned by ThiefKit (cast_ult, _tick,
## _drop_holds).

const RING_COL := Color("9a5cff")      # the ring and the blades: her signature violet (the source's is cyan)
const RIM_COL := Color("eadcff")       # the outer band, where blades hit harder: her violet run hot
const BLADE_TIP := Color("ffffff")
const BLADE_SPEED := 30.0              # m/s: the cosmetic blade's flight (the hit lands when it arrives)
const ORBITERS := 3                    # blades circling her while it runs
const ORBIT_R := 0.9                   # m
const DANCE := "thf_encore_dance"
const DANCED_OVER := ["thf_lmb_r", "thf_lmb_l"]   # her plain throws don't break the dance (the bolts still fly)
const PULSE_FADE := 7.0                # per s: how fast a beat's pulse leaves the ring
const PULSE_R := 0.02                  # of the radius: the ring's swell on a beat

var k: ThiefKit
var st := {}                           # running: {t, next, n, hits: {foe id: blades landed}}
var casts := 0                         # (tests, demo)
var blades := 0                        # blades landed
var rim_blades := 0                    # of which from the outer band
var pulse := 0.0                       # 1 on a beat, fading
var beat := 0                          # the volleys so far this cast (which hand throws)

func _init(kit: ThiefKit) -> void:
	k = kit

func data() -> Dictionary:
	return k.x_def()

func running() -> bool:
	return not st.is_empty()

## The ring's radius now: it grows from r0 to reach over `grow`, then holds.
func radius() -> float:
	var d := data()
	var gk := clampf(float(st.get("t", 0.0)) / float(d["grow"]), 0.0, 1.0)
	return lerpf(float(d["r0"]), float(d["reach"]), 1.0 - pow(1.0 - gk, 2.0))

## X pressed: the ring starts growing (a ring with nobody in it still runs).
func start() -> void:
	var d := data()
	casts += 1
	st = {"t": 0.0, "next": float(d["grow"]), "n": int(d["shots"]), "hits": {}}
	beat = 0
	var h := k.h
	k.play("thf_encore")
	k.m.fx.word(h.pos + Vector3(0, 2.7, 0), String(d["short"]).to_upper(), RIM_COL, false)
	k.vfx("encore", h.pos, null, {"r": float(d["reach"])})
	k.m.later(float(d["grow"]), func(): if running(): k.m.sfx("dj_encore_whirr", h.pos, -6.0, 1.0))
	h.dashes = h.max_dashes()             # the source's info card: it resets the cartwheel
	DashReset.cue(h)

## The cast ends (its time ran out, a merge, a knock): nothing more flies.
func drop() -> void:
	st = {}
	if k.anim_id == DANCE:
		k.play("")
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
	pulse = maxf(0.0, pulse - dt * PULSE_FADE)
	_keep_dancing(d)
	if float(st["t"]) >= float(st["next"]) and int(st["n"]) > 0:
		st["n"] = int(st["n"]) - 1
		st["next"] = float(st["next"]) + float(d["time"]) / float(d["shots"])
		_volley(d)
	_draw_ring(d)
	_orbit(d)
	if int(st["n"]) <= 0 and float(st["t"]) >= float(d["grow"]) + float(d["time"]):
		drop()                             # a plain fade: no final burst

## From the first beat on the dance runs, on the beat: back in time after a flip, a Bola or anything else she did.
func _keep_dancing(d: Dictionary) -> void:
	var into := float(st["t"]) - float(d["grow"])
	if into < 0.0 or k.anim_id == DANCE or not k.vault.is_empty() or k.landing_due:
		return
	var other := HunterAnim.km_def(k.anim_id)
	var other_left: float = float(other["keys"][-1][0]) - (k.m.time - k.anim_at) if not other.is_empty() else 0.0
	if k.anim_id == "thf_encore" or other_left <= 0.0:
		k.anim_id = DANCE
		k.anim_at = k.m.time - into

## The ring everyone sees: it grows out from her, then rides with her; a dashed line marks the outer band. A lit rim
## over a faint inner wash (never a solid disc that hides who is in it); it brightens and swells a little on
## every beat.
func _draw_ring(d: Dictionary) -> void:
	var r := radius()
	AimKit.circle(k.h, "ult", {"self": true, "r": r * (1.0 + PULSE_R * pulse), "col": RING_COL, "col2": RIM_COL,
			"all": true, "ticks": true, "hot": pulse, "alpha": 1.2 + 0.8 * pulse})
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

## A beat: the ring pulses and one blade leaves her hand at every foe inside the ring (each at most `shots` times).
func _volley(d: Dictionary) -> void:
	var h := k.h
	var r := radius()
	var right := beat % 2 == 0
	var thrown := false
	beat += 1
	pulse = 1.0
	for f in k.foes_in(h.pos, r):
		if f is Kin or not k.sees(f):
			continue
		var key: int = f.get_instance_id()
		var got := int((st["hits"] as Dictionary).get(key, 0))
		if got >= int(d["shots"]):
			continue
		st["hits"][key] = got + 1
		var rim := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z).length() > r * float(d["rim"])
		_blade(f, rim, right)
		thrown = true
	if thrown:
		k.vfx("encore_throw", k.hand_pos(right))

## A cosmetic blade flies from her hand; the hit lands when it arrives.
func _blade(f: Ent, rim: bool, right: bool) -> void:
	var h := k.h
	var from := k.hand_pos(right)
	var to := f.pos + Vector3(0, 1.0, 0)
	var dv := Vector2(to.x - from.x, to.z - from.z)
	var dist := dv.length()
	var n0: int = k.m.shots.size()
	k.m.spawn_shot(h, from, dv.normalized() * BLADE_SPEED, 0.0, dist / BLADE_SPEED, 0.08, RING_COL, {"cos": true})
	if k.m.shots.size() > n0:
		k.fx().ride(k.m.shots[-1], "blade", RIM_COL if rim else RING_COL, BLADE_TIP, 0.9, 0.22)
	k.m.later(dist / BLADE_SPEED, func(): _hit(f, rim))

## A blade arrives: its damage (more from the outer band, which also blights), a violet flash (brighter from the
## band), Marks refreshed, and the bond for a rival hunter.
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
	var dealt := f.hurt(dmg * k.power("x"), h, o)
	if dealt <= 0.0:
		return
	blades += 1
	if rim:
		rim_blades += 1
		if not was_blighted:
			# once, as the blight lands (above the damage numbers, so they don't overprint)
			k.m.fx.word(f.pos + Vector3(0, 3.0, 0), "BLIGHT", Color("b08aff"), false)
	k.vfx("encore_hit", f.pos + Vector3(0, 1.0, 0), null, {"rim": rim})
	k.refresh_marks()
	HeroUlt.landed(k, f)
