class_name KinSteal
extends RefCounted
## Stealing Boki wisps (DECISIONS 2026-11-09 "Soul-linked Boki ride with you as wisps", Stealing;
## briefs/boki-art/WISP_DESIGN_OPEN.md Q6/Q8; decision 0041). Only with Boki wisps on (KinWisp).
##   - A downed hunter's Boki wisp breaks loose where they fell and floats for loose_s. Anyone who holds
##     interact for grab_s within grab_r grabs it, its own hunter too once revived. Ungrabbed, it goes home.
##   - A thief carries at most carry_max stolen wisps: each one's carry passives at passive_k (clamped with the
##     rest at the carry cap, Hunter._refresh_kin_stats) and one summon this match (summon_k of its window, at
##     least summon_min_s) on the Summon key while their own Boki is resting or not riding with them.
##   - A thief who goes down or dies scatters what they carry: loose again where they fell.
##   - Grabbing someone else's wisp leaves a soul echo: its species in your Field Book (Care "echo").
##   - At match end every loose or stolen wisp goes home (match_end). The save never moved it: nothing is lost.
## The Kin keeps its own hunter in home_h; owner_h is whoever it rides with now (the thief while stolen), so the
## orbit, the summon's leash and the hit credit follow the carrier.
## Online: the Boki's own game decides (loose, scatter, home, and the grabs and summons it is asked for). A grab
## or a stolen summon from another game is a kcmd event ("wgrab"/"wsum", extra = the Boki's id); the kin
## snapshot carries the loose seconds, the carrier and the used summon (KinNet, Net 0.30.0).

const BOB_M := 0.12      # m a loose wisp bobs up and down
const BOB_HZ := 0.8      # bobs per second
const POP_M := 2.5       # m from the fallen hunter it floats: clear of their stomp and revive ring (Life revive_radius)

static func rules() -> Dictionary:
	return KinSummon.rules()["steal"]

## Floating loose, free to grab?
static func loose(k: Kin) -> bool:
	return k.loose_t > 0.0

## Riding with someone other than its own hunter?
static func stolen(k: Kin) -> bool:
	return k.home_h != null and k.owner_h != k.home_h

## Out of its own hunter's hands: the death and loss rules leave it alone (KinLoss.on_owner_out).
static func taken(k: Kin) -> bool:
	return loose(k) or stolen(k)

## How many stolen wisps a hunter carries.
static func count(h: Hunter) -> int:
	var n := 0
	for k in h.m.kins:
		if k.owner_h == h and stolen(k) and not k.dead:
			n += 1
	return n

## Each carried stolen wisp's carry passives at passive_k, added to a hunter's stat sums (Hunter._refresh_kin_stats).
static func add_passives(h: Hunter, sums: Dictionary) -> void:
	for k in h.m.kins:
		if k.owner_h != h or not stolen(k) or k.dead or k.ks == null:
			continue
		var f := float(rules()["passive_k"])
		for ps in k.ks.carry_passives:
			sums[ps["stat"]] = float(sums.get(ps["stat"], 0.0)) + float(ps["amount"]) * f

## The step of a wisp that is loose or may break loose (KinWisp.ride). True when it handled it.
static func ride(k: Kin, dt: float) -> bool:
	if loose(k):
		if k.remote:
			k.net_follow(dt)
			return true
		k.loose_t -= dt
		if k.loose_t > 0.0:
			return true
		go_home(k)
		return false
	var o := k.owner_h
	if k.remote or o == null or k.home_h == null or k.state != "shoulder":
		return false
	if stolen(k) and (o.downed or o.out or o.extracted):
		break_loose(k, o.pos)          # the thief fell: what they carry scatters
	elif not stolen(k) and o.downed and not k.back_home:
		break_loose(k, o.pos)
	elif not (o.downed or o.out):
		k.back_home = false
	return loose(k)

## Its wisp breaks loose at shoulder height, popping off its fallen rider (the Boki's own game).
static func break_loose(k: Kin, at: Vector3) -> void:
	var thief := k.owner_h if stolen(k) else null
	var a := float(k.m.kins.find(k) % 7) * 2.1          # (each wisp off its own way)
	at += Vector3(cos(a), 0.0, sin(a)) * POP_M
	if thief:
		k.m.add_feed("%s's %s scattered from %s" % [k.home_h.pname, k.rec.get("name", "Boki"), thief.pname])
	_ride_with(k, k.home_h)
	k.loose_t = float(rules()["loose_s"])
	k.pos = at + Vector3(0, KinWisp.SHOULDER_Y, 0)
	k.prev = k.pos
	k.m.fx.burst(k.pos, k.sp.get("glow", k.sp["color"]), 10, 2.5)

## Back to its own hunter's shoulder (loose too long, or the match is over). A downed hunter keeps it this time.
static func go_home(k: Kin) -> void:
	k.loose_t = 0.0
	k.back_home = true
	_ride_with(k, k.home_h)
	k.stow()
	k.m.fx.ring(k.home_h.pos, 1.2, Color(k.sp.get("glow", k.sp["color"]), 0.8), 0.3)

static func _ride_with(k: Kin, h: Hunter) -> void:
	k.owner_h = h
	k.team = h.team

## The prompt for a loose wisp within reach, and the grab once interact is held long enough
## (Match._update_interact). Empty when none is near.
static func interact_for(m: Match, h: Hunter, want: bool, dt: float) -> Dictionary:
	var r := rules()
	var near: Kin = null
	var best := float(r["grab_r"])
	for k in m.kins:
		if loose(k) and not k.dead and h.flat_dist(k) < best:
			best = h.flat_dist(k)
			near = k
	if near == null:
		return {}
	var key := Settings.key_cap("interact")
	var own := near.home_h == h
	if not own and count(h) >= int(r["carry_max"]):
		var full := "Hands full: you carry %d stolen wisps" % count(h)
		return {"kind": "wisp", "ent": near, "label": full, "col": Color("a2a8bb")}
	var held := float(h.get_meta("wgrab", 0.0)) + dt if want else 0.0
	h.set_meta("wgrab", held)
	if held >= float(r["grab_s"]) and not h.remote:
		h.set_meta("wgrab", 0.0)
		if near.remote:
			KinNet.event(m, "wgrab", h, Vector3.INF, near.nid)
		else:
			grab(near, h)
	var boki := String(near.rec.get("name", "Boki"))
	var label := "Hold %s to grab %s's %s" % [key, near.home_h.pname, boki]
	if own:
		label = "Hold %s to take %s back" % [key, boki]
	return {"kind": "wisp", "ent": near, "label": label, "col": near.sp.get("glow", near.sp["color"])}

## Into a hunter's orbit: home if it is theirs, else stolen. Refused when it is not loose or their hands are full.
static func grab(k: Kin, h: Hunter) -> bool:
	if not loose(k) or h.downed or h.out or (h != k.home_h and count(h) >= int(rules()["carry_max"])):
		return false
	k.loose_t = 0.0
	_ride_with(k, h)
	k.stow()
	_grabbed(k, h)
	return true

## Every game: the catch moment, and the soul echo for a local thief.
static func _grabbed(k: Kin, h: Hunter) -> void:
	var glow: Color = k.sp.get("glow", k.sp["color"])
	k.m.fx.ring(h.pos, 1.4, Color(glow, 0.8), 0.3)
	k.m.sfx("kin_happy", h.pos, -6.0, Unique.voice(k.rec))
	if h == k.home_h:
		return
	k.m.add_feed("%s grabbed %s's %s" % [h.pname, k.home_h.pname, k.rec.get("name", "Boki")])
	if h == k.m.player:
		Care.dex_mark(k.species, "echo")

## Summon with your own Boki resting or away: the first stolen wisp you carry that still has its one summon
## bursts out (KinSummon.press). False when there is none.
static func press(h: Hunter) -> bool:
	for k in h.m.kins:
		if k.owner_h == h and stolen(k) and k.wisp and not k.stolen_summoned and k.summon:
			if k.remote:
				KinNet.event(h.m, "wsum", h, Vector3.INF, k.nid)
			else:
				summon(k)
			return true
	return false

## Its one summon for the thief: summon_k of its window, at least summon_min_s, on its AI for the thief's side.
static func summon(k: Kin) -> void:
	if k.stolen_summoned or not k.wisp or not stolen(k):
		return
	var r := rules()
	k.stolen_summoned = true
	k.summon.burst(maxf(float(r["summon_min_s"]), ceilf(k.summon.dur * float(r["summon_k"]))))

## A "wgrab" or "wsum" event: the Boki's own game does it, and its snapshot tells the rest.
static func on_net(m: Match, h: Hunter, kind: String, kin_id: String) -> void:
	var k = m.ents_by_id.get(kin_id, null)
	if not (k is Kin) or (k as Kin).remote:
		return
	if kind == "wgrab":
		grab(k, h)
	else:
		summon(k)

## The kin snapshot's steal fields (KinNet): [loose seconds, carrier id or "", its stolen summon used].
static func net_extra(k: Kin) -> Array:
	return [snappedf(k.loose_t, 0.1), k.owner_h.nid if stolen(k) else "", int(k.stolen_summoned)]

static func apply_net(k: Kin, loose_s: float, carrier: String, used: bool) -> void:
	if k.home_h == null:
		return
	k.loose_t = loose_s
	k.stolen_summoned = used
	var c = k.m.ents_by_id.get(carrier, null) if carrier != "" else null
	var to: Hunter = c if c is Hunter else k.home_h
	if to != k.owner_h:
		_ride_with(k, to)
		if to != k.home_h:
			_grabbed(k, to)

## Its look while loose: bobbing where it broke loose (KinWisp.render).
static func render(k: Kin) -> void:
	k.global_position = k.pos + Vector3(0, sin(k.m.time * BOB_HZ * TAU) * BOB_M, 0)
	BokiWispLook.pose(k.model, k.m.time)

## Match end: every loose or stolen wisp goes home to its own hunter.
static func match_end(m: Match) -> void:
	for k in m.kins:
		if taken(k) and k.home_h and not k.dead:
			go_home(k)
