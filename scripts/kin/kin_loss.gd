class_name KinLoss
extends RefCounted
## Losing a Boki (docs/decisions/0008). Numbers: content/rules/boki_system.json "loss".
##   - Tiers below loss_min_tier are safe: when you die your Boki keeps out of sight and goes home with you ("away").
##   - From loss_min_tier up, when you die your Boki drops dazed and GUARDS the spot, with no box, no teleport:
##     one that was on you stands beside your deathbox, one that was out fighting stays where it stood. Revived,
##     you run into it for the usual 3.5s cradle (KinDowned) and it is yours again. An enemy can scan it
##     like any knocked-out Boki (Capture); a teammate cannot. A scanned Boki sits in the captor's box (KinBond).
##   - At the end of the match the Boki's fate is written to the save by after_match(): "home", "ransom" (nobody took
##     it) or "captured_by:<name>". A flagged Boki cannot be brought into a match until the market clears it.
## A guarding Boki is a Kin in state "dazed" that has an owner (a wild dazed Boki has none), so it needs no flag
## of its own and the other games see it through the ordinary kin snapshot.

static func rules() -> Dictionary:
	return KinCommand.rules()["loss"]

## Can a Boki be lost in this tier?
static func at_risk(tier: int) -> bool:
	return tier >= int(rules()["loss_min_tier"])

## This match puts Boki at risk (not practice or the tutorial).
static func risky_match(m) -> bool:
	return at_risk(m.tier) and not m.opts.get("training", false) and not m.opts.get("tutorial", false)

# ------------------------------------------------------------------ in the match: the guarding Boki
static func guarding(k: Kin) -> bool:
	return k.state == "dazed" and k.owner_h != null and not k.dead

## Can this hunter scan that knocked-out Boki? A wild one, or a rival's guard; never your own or a teammate's.
static func scannable_by(h: Hunter, k: Kin) -> bool:
	return k.state == "dazed" and not k.dead and (k.owner_h == null or k.owner_h.team != h.team)

## The hunter died: safe tiers send the Boki home with them, the others drop it to guard. box_pos is
## where the deathbox went (Vector3.INF when there is none).
static func on_owner_out(m, h: Hunter, k: Kin, box_pos: Vector3) -> void:
	m.giant_free(k)
	if Loaner.is_loaner(k.rec) or not risky_match(m):
		k.state = "away"            # never lost: it keeps out of sight and comes back if you are revived
		return
	if h.remote:
		return                       # (their own game drops it and the snapshot tells us)
	var on_you: bool = k.state in ["shoulder", "bench", "away"] or k.with_owner()
	var at := k.pos
	if on_you:
		at = box_pos if box_pos != Vector3.INF else h.pos
		var a := float(m.kins.find(k) % 7) * 2.1
		at += Vector3(cos(a), 0.0, sin(a)) * float(rules()["guard_r"])
	at = _ground(m, at)
	var rec: Dictionary = k.rec.duplicate(true)
	if at == Vector3.INF:
		# no ground to stand on (the abyss): it is swept away and nobody can take it
		k.dead = true
		k.visible = false
		if h == m.player:
			m.player_lost.append({"uid": String(rec.get("uid", "")), "kin": null, "holder": null, "rec": rec})
			m.add_feed("%s was lost with you to the abyss" % rec.get("name", "Your Boki"))
		return
	k.teleport(at)
	_stand_guard(m, h, k)
	m.kstat["left"] += 1
	if h == m.player:
		m.player_lost.append({"uid": String(rec.get("uid", "")), "kin": k, "holder": null, "rec": rec})
		m.add_feed("%s is guarding your box: get revived and run into it, or a rival can scan it" % rec.get("name", "Your Boki"))

## A Boki a captor had in their box drops where they fell, dazed, guarding for its owner.
static func spawn_guard(m, owner: Hunter, rec: Dictionary, at: Vector3) -> Kin:
	at = _ground(m, at)
	if at == Vector3.INF:
		return null
	var k := Kin.new()
	k.init_kin(m, m.next_id(owner.nid + "k"), rec["species"], rec, owner)
	m.add_child(k)
	m.kins.append(k)
	m.ents_by_id[k.nid] = k
	k.teleport(at)
	_stand_guard(m, owner, k)
	return k

static func _stand_guard(m, owner: Hunter, k: Kin) -> void:
	k.state = "dazed"
	k.hp = 1.0
	k.dazed_t = 1e9                      # it waits as long as it takes
	k.fly = {}
	k.target = null
	k.chase_target = null
	k.hold_at = Vector3.INF
	k.pend_skill = Vector3.INF
	k.pend_slot = ""
	k.vel = Vector3.ZERO
	k.scan_by = null
	k.rescue_t = 0.0
	k.rescue_on = false
	k.rescue_block = 0.0
	k.down_t = 0.0
	k.down_void = false
	k.dead = false
	k.visible = true
	k.lost_from = "you" if (owner == m.player or k.lost_from == "you") else owner.pname
	k.lost_uid = String(k.rec.get("uid", ""))
	k.lost_owner = owner
	m.fx.burst(k.pos + Vector3(0, 0.6, 0), Color("fff2a0"), 10, 2.0)

static func _ground(m, at: Vector3) -> Vector3:
	if m.world.is_void(at.x, at.z):
		at = m.world.free_spot_near(at, [], 1.0, 0.4, 40.0)
	if m.world.is_void(at.x, at.z):
		return Vector3.INF
	at.y = m.world.ground_at(at.x, at.z)
	return at

## Each step while it guards (Kin._sim_dazed): its owner, once up, can cradle it.
static func tick_guard(k: Kin, dt: float) -> void:
	var h := k.owner_h
	if h == null:
		return
	if h.out or h.extracted:
		k.rescue_t = 0.0
		k.rescue_on = false
		return
	KinDowned.step_rescue(k, h, dt)

## The Boki a hunter is cradling right now, if any (a guard may sit outside their kin slots).
static func rescuing(h: Hunter) -> Kin:
	for k in h.m.kins:
		if k.rescue_on and k.owner_h == h and (k.state == "downed" or guarding(k)):
			return k
	return null

## The cradle finished (KinDowned.come_round): it is the owner's again, in a slot.
static func reclaimed(k: Kin) -> void:
	if k.lost_owner == null:
		return
	var h := k.owner_h
	var uid := k.lost_uid
	k.lost_from = ""
	k.lost_uid = ""
	k.lost_owner = null
	for L in k.m.player_lost.duplicate():
		if String(L["uid"]) == uid:
			k.m.player_lost.erase(L)
	if h == null:
		return
	if h.kin != k and h.kin2 != k:
		if h.kin == null or (h.kin as Kin).dead:
			h.kin = k
			h.apply_kin_bonus()
		else:
			h.kin2 = k
	if h.kin2 == k:
		k.bench()

## Where each of your lost Boki ends up when the match is over: [{uid, fate, holder, rec}]. fate is "ransom" (nobody took
## it, or its taker is out), "rival" (a rival who is still in has it), "squad" or "self".
static func resolve(m) -> Array:
	var out: Array = []
	for L in m.player_lost:
		var fate := "ransom"
		var who := ""
		var holder = L.get("holder")
		if holder is Hunter:
			var hh: Hunter = holder
			if hh == m.player:
				fate = "self"
			elif hh.team == m.player.team:
				fate = "squad" if not hh.out else "ransom"
				who = hh.pname
			elif not hh.out:
				fate = "rival"
				who = hh.pname
		out.append({"uid": L["uid"], "fate": fate, "holder": who, "rec": L["rec"]})
	return out

# ------------------------------------------------------------------ after the match: the save
## The outcome string for a resolved fate.
static func outcome_of(fate: String, holder: String) -> String:
	match fate:
		"rival":
			return "captured_by:" + holder
		"ransom":
			return "ransom"
	return "home"

## Writes what became of a Boki into the save. boki is its roster record; outcome is "home" (clears any
## flag), "ransom" (at the Ransom House, waiting) or "captured_by:<player name>" (lost to that player).
## The flags are plain optional fields: a save without them is a Boki that is fine.
static func after_match(save: Dictionary, boki: Dictionary, outcome: String) -> void:
	clear(boki)
	var stamp := {"match": int(save.get("matches", 0)), "t": int(Time.get_unix_time_from_system())}
	if outcome == "ransom":
		boki["ransom"] = stamp
	elif outcome.begins_with("captured_by:"):
		stamp["by"] = outcome.substr("captured_by:".length())
		boki["lost_to"] = stamp
	elif outcome != "home":
		push_warning("KinLoss.after_match: unknown outcome '%s'" % outcome)

## Resolved (bought back, won back): the flags come off.
static func clear(boki: Dictionary) -> void:
	boki.erase("ransom")
	boki.erase("lost_to")

## Waiting at the Ransom House or lost to a player.
static func held(boki: Dictionary) -> bool:
	return boki.has("ransom") or boki.has("lost_to")

## Can it be brought into a match?
static func selectable(boki: Dictionary) -> bool:
	return not held(boki)
