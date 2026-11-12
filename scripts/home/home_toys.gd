class_name HomeToys
extends RefCounted
## The Boki base's playthings (content/rules/toys.json, GARDEN.md section 4): a ball, a climbing post, a
## splash tub, a warm stone and a dig patch, placed in build mode and used on their own. Only while
## farm_build.json base_mode is on.
## An idle Boki with room to be happier picks a toy by its lean and traits (a Flying or Rock Boki likes
## the post, Water and Ice the tub, Fire the stone, Grass and Bug the patch), walks to it, plays, and gains
## the toy's stat through Care.add_stat. Its most-used toy becomes its favourite, picked first (FavToy).
## A second Boki may join the first; two hot tempers squabble and the newcomer huffs off.
## k["play"] = {u: toy uid, phase: "go" | "play", t: seconds}. home.gd calls pick, step and pose.

const SPOT_R := 1.15          # tiles from a toy's centre to where a Boki stands
const SPOT_GAP := 0.9         # m: a toy's standing place keeps this far from a Boki lying down
const CROWD := 1.9            # m: a toy with a Boki lying this close to it is left alone (it would push through them)
const ARRIVE := 0.7           # tiles: close enough to start
const HUFF_SECS := 1.5        # the growl after a squabble
const BALL_R := 0.28          # the ball's resting height (its radius)

var h

func _init(home) -> void:
	h = home

static func rules() -> Dictionary:
	return Content.rules("toys")

## The toys on the layout: [{u, id, pos}].
func toys() -> Array:
	var out: Array = []
	var defs: Dictionary = rules()["toys"]
	for e in h.hb.L()["deco"]:
		if defs.has(String(e["id"])):
			out.append({"u": int(e["u"]), "id": String(e["id"]), "pos": HomeLayout.deco_center(e)})
	return out

## Sets the clip a rigged Boki plays for what it is doing (kact: munch at a feeder, a toy's clip at a toy); true
## when this Boki has a rig, which poses its own body.
func _act(k: Dictionary, n: Node3D) -> bool:
	var act := ""
	var eat: Variant = k.get("eat")
	var play: Variant = k.get("play")
	if eat is Dictionary and eat["phase"] == "eat":
		act = "munch"
	elif play is Dictionary and play["phase"] == "play":
		act = String(rules()["toys"].get(String(_toy(int(play["u"])).get("id", "")), {}).get("clip", ""))
	if act != "" or n.has_meta("kact_home"):
		n.set_meta("kact", act)
		if act != "":
			n.set_meta("kact_home", true)
		else:
			n.remove_meta("kact_home")
	return n.has_node("Body/Flex/BokiRig")

func _toy(u: int) -> Dictionary:
	for t in toys():
		if int(t["u"]) == u:
			return t
	return {}

## Who has committed to a toy (walking to it or playing), in the order they chose it.
func players(u: int) -> Array:
	return h.kins.filter(func(o): return o.has("play") and int(o["play"]["u"]) == u)

## The element this Boki leans to: its strongest lean (Evo.lean), else its species' element.
static func lean_of(rec: Dictionary) -> String:
	var top := String(Evo.lean(rec)[0])
	if top == "":
		top = BokiLines.element_of(String(rec.get("species", "")))
	return top.to_lower()

## How much a Boki fancies a toy: its trait for that toy, and double the lean the toy is made for.
static func weight(rec: Dictionary, toy_id: String) -> float:
	var R := rules()
	var def: Dictionary = R["toys"][toy_id]
	var w := 1.0 + float(R["trait_weight"]) * float(rec["traits"].get(String(def["trait"]), 0.5))
	if (def["likes"] as Array).has(lean_of(rec)):
		w += float(R["like_weight"])
	if FavToy.of(rec) == toy_id:
		w *= float(R["fav_weight"])
	return w

## An idle Boki looks for a toy: true when it has set off for one. want: it is bored or curious (BaseLife.choose),
## so it goes whatever its joy and the pick chance say.
func pick(k: Dictionary, want := false) -> bool:
	var R := rules()
	var rec: Dictionary = k["rec"]
	if not FarmUnlocks.base_mode() or not h.visit.is_empty() or k.has("play"):
		return k.has("play")
	if not want and (Care.need(rec, "joy") >= float(R["joy_below"]) or randf() > float(R["pick_chance"])):
		return false
	if not want and h.life and not h.life.machine(k).is_in(BaseLife.S.ROAM):
		return false      # a Boki mentoring, eating or napping (BaseLife) is not pulled off to a toy
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	var weights := {}
	var total := 0.0
	for t in toys():
		var tp: Vector3 = t["pos"]
		var full: bool = players(int(t["u"])).size() >= int(R["max_players"])
		if h.world.island_of(tp.x, tp.z) != here or full or crowded(k, tp):
			continue
		var company := float(R["join_weight"]) if not players(int(t["u"])).is_empty() else 1.0
		weights[int(t["u"])] = weight(rec, String(t["id"])) * company
		total += weights[int(t["u"])]
	if weights.is_empty():
		return false
	var roll := randf() * total
	for u in weights:
		roll -= float(weights[u])
		if roll <= 0.0:
			k["play"] = {"u": u, "phase": "go", "t": 0.0, "slot": _free_slot(u)}
			k["t"] = 30.0
			k.erase("stare")
			return true
	return false

## The lowest place round a toy nobody has taken.
func _free_slot(u: int) -> int:
	var taken: Array = players(u).map(func(o): return int(o["play"]["slot"]))
	var slot := 0
	while taken.has(slot):
		slot += 1
	return slot

func _busy(k: Dictionary) -> bool:
	var rec: Dictionary = k["rec"]
	return k.get("busy", false) or k.has("chase") or k.has("job") or k.has("fetch") or k.has("bath") or k.has("eat") \
			or k.has("called_t") or k.has("going_in") or float(k.get("nap_t", 0.0)) > 0.0 \
			or Care.need(rec, "food") < 30.0 or Care.need(rec, "energy") < 22.0

func _spot(k: Dictionary, t: Dictionary) -> Vector3:
	return stand(k, t["pos"], 0.8 + float(k["play"]["slot"]) * PI)

## A place to stand beside the toy at `tp`, on its side `a` (rad): open ground, clear of any Boki parked there.
func stand(k: Dictionary, tp: Vector3, a: float) -> Vector3:
	var p := tp + Vector3(cos(a), 0, sin(a)) * SPOT_R
	var parked := parked_at(k, KinAvoid.parked)
	if k.has("play"):
		for o in players(int(k["play"]["u"])):
			if o != k:
				parked.append(o["goal"])      # the place a Boki on its way to this toy has taken
	var taken := parked.any(func(q): return Vector2(q.x - p.x, q.z - p.z).length() < SPOT_GAP)
	if taken or h.world.is_void(p.x, p.z) or h.world.occupy(p.x, p.z, 0.3, 0.0, true) != 0.0:
		return h.world.free_spot_near(p, parked, SPOT_GAP)
	return p

## Where the Boki (other than k) that `stays` (KinAvoid.lying or .parked) are.
func parked_at(k: Dictionary, stays: Callable) -> Array:
	return h.kins.filter(func(o): return o != k and stays.call(o)).map(func(o): return o["pos"])

## Is a Boki lying right by the toy at `tp`, so playing there would mean pushing through it?
func crowded(k: Dictionary, tp: Vector3) -> bool:
	return parked_at(k, KinAvoid.lying).any(func(q): return Vector2(q.x - tp.x, q.z - tp.z).length() < CROWD)

## Per frame, from home.gd's _care_step: walk to the toy, play, finish. True while it owns the Boki.
func step(k: Dictionary, d: float) -> bool:
	if not k.has("play"):
		return false
	var p: Dictionary = k["play"]
	var t := _toy(int(p["u"]))
	var blocked: bool = p["phase"] == "go" and not t.is_empty() and (crowded(k, t["pos"]) or KinAvoid.shut(k))
	if t.is_empty() or not FarmUnlocks.base_mode() or _busy(k) or blocked:
		_stop(k)
		return false
	var pos: Vector3 = k["pos"]
	k["goal"] = _spot(k, t)
	if p["phase"] == "go":
		p["t"] = float(p["t"]) + d
		if Vector2(pos.x - k["goal"].x, pos.z - k["goal"].z).length() < ARRIVE:
			_arrive(k, t)
		elif float(p["t"]) > float(rules()["go_timeout"]):
			_stop(k)
			return false
		return k.has("play")
	if t["id"] == "toy_tub":
		k["joy_t"] = maxf(float(k.get("joy_t", 0.0)), 0.3)
	p["t"] = float(p["t"]) - d
	if float(p["t"]) <= 0.0:
		_finish(k, t)
	return true

## Reaching the toy: play, or (with someone already there) share it or squabble over it.
func _arrive(k: Dictionary, t: Dictionary) -> void:
	var R := rules()
	var p: Dictionary = k["play"]
	var others: Array = players(int(t["u"])).filter(func(o): return o != k and o["play"]["phase"] == "play")
	var hot := float(R["squabble_temper"])
	if others.size() >= 1 and _temper(k) > hot and _temper(others[0]) > hot:
		h._emote(k, "!", true)
		h._emote(others[0], "!", true)
		k["huff_t"] = HUFF_SECS
		Care.change(k["rec"], "joy", -3.0)
		_bond(k, others[0], "bond_squabble")      # a squabble over a toy builds rivalry (BaseLife)
		_stop(k)
		k["t"] = float(R["sulk_secs"])
		return
	p["phase"] = "play"
	FarmTutorial.event("play")
	var secs: Array = R["play_secs"]
	p["t"] = randf_range(float(secs[0]), float(secs[1]))
	p["secs"] = p["t"]
	if others.size() >= 1:
		h._emote(k, "★", true)
		_bond(k, others[0], "bond_share")      # sharing one builds friendship

## Two Boki at one toy change their bond by base_life.json's `key` (base life on only).
func _bond(k: Dictionary, o: Dictionary, key: String) -> void:
	if h.life:
		h.life.add_bond(k["rec"], o["rec"], float(h.life.R[key]))

func _temper(k: Dictionary) -> float:
	return float(k["rec"]["traits"].get("temper", 0.5))

func _finish(k: Dictionary, t: Dictionary) -> void:
	var R := rules()
	var rec: Dictionary = k["rec"]
	var def: Dictionary = R["toys"][t["id"]]
	var stat := String(def["stat"])
	var gained := Care.add_stat(rec, stat, GardenZones.train_gain(rec, int(R["stat_gain"])))
	FavToy.log_play(rec, String(t["id"]), float(k["play"]["secs"]))
	Care.change(rec, "joy", float(R["joy_gain"]))
	if randf() < float(def.get("snack", 0.0)):
		var item := String(R["snack_item"])
		Save.add_item(item, 1)
		h._toast("%s dug up a %s" % [rec["name"], String(Care.FOODS[item]["name"]).to_lower()])
	h._emote(k, "♥" if gained > 0 else "♪", true)
	GardenFirstDay.mark("toy", h)
	if gained > 0:
		h.fx.burst(k["pos"] + Vector3(0, 0.9, 0), Care.STATS[stat]["col"], 7, 2.0, 0.5)
	_stop(k)
	k["t"] = 2.0

## It stops (done, interrupted or squabbled): the pose and the toy go back to rest.
func _stop(k: Dictionary) -> void:
	var p: Dictionary = k["play"]
	k.erase("play")
	var n := k["node"] as Node3D
	n.set_meta("pose", "")
	var ball := _ball(int(p["u"]))
	if ball and players(int(p["u"])).is_empty():
		ball.position = Vector3(0, BALL_R, 0)

func _ball(u: int) -> Node3D:
	var tn: Node3D = h.hb.nodes.get(u)
	return tn.get_node_or_null("Ball") as Node3D if tn else null

## The play pose, over the usual bounce (after _quirk): readable at a glance. The ball hops and rolls, the
## Boki leans in and nudges it; the post is climbed and slid down; the tub is splashed in (the "happy"
## wiggle comes from joy_t in step); the stone is leaned on and basked on, slow breaths; the patch is dug at,
## paws going, dirt flying. A squabble leaves a short growl.
func pose(k: Dictionary, n: Node3D, d: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	var rigged := _act(k, n)
	if float(k.get("huff_t", 0.0)) > 0.0:
		k["huff_t"] = float(k["huff_t"]) - d
		n.set_meta("pose", "growl" if float(k["huff_t"]) > 0.0 else "")
	if not k.has("play") or k["play"]["phase"] != "play" or body == null:
		return
	var t := _toy(int(k["play"]["u"]))
	if t.is_empty():
		return
	var tp: Vector3 = t["pos"]
	n.rotation.y = atan2(-(tp.x - k["pos"].x), -(tp.z - k["pos"].z))
	var s := Time.get_ticks_msec() / 1000.0 + float(absi(String(k["rec"]["uid"]).hash()) % 10)
	match String(t["id"]):
		"toy_ball":
			var hop := absf(sin(s * 6.0))
			if not rigged:
				body.position.y = hop * 0.3
				body.rotation.x = -0.25 * sin(s * 3.0)
			n.set_meta("pose", "nudge")
			var ball := _ball(int(t["u"]))
			if ball:
				ball.position = Vector3(sin(s * 3.0) * 0.4, BALL_R + absf(sin(s * 6.0 + 1.0)) * 0.3, cos(s * 3.0) * 0.4)
		"toy_post":
			var climb := 0.5 - 0.5 * cos(fposmod(s * 0.9, TAU))
			if not rigged:
				body.position.y = climb * 0.9
				body.position.z = -0.35
				body.rotation.x = -0.5
			n.set_meta("pose", "alert" if climb > 0.8 else "")
		"toy_tub":
			if not rigged:
				body.position.y = 0.08 + absf(sin(s * 9.0)) * 0.12
				body.rotation.z = sin(s * 12.0) * 0.2
			if randf() < d * 5.0:
				h.fx.burst(tp + Vector3(0, 0.5, 0), Color("8fd0ff"), 5, 2.0, 0.4)
		"toy_stone":
			body.position.y = 0.02 + sin(s * 1.6) * 0.03
			body.rotation.x = -0.3
			n.set_meta("pose", "comfort")
			if randf() < d * 1.2:
				h.fx.burst(tp + Vector3(0, 0.6, 0), Color("ffb066"), 2, 0.8, 0.9, -1.0)
		"toy_vent":
			body.position.y = 0.55 + sin(s * 2.0) * 0.12
			n.set_meta("pose", "alert")
			if randf() < d * 3.0:
				h.fx.burst(tp + Vector3(0, 0.2, 0), Color("cfeeff"), 3, 1.2, 0.8, -1.0)
		"toy_dig":
			body.position.y = absf(sin(s * 10.0)) * 0.05
			body.rotation.x = -0.45 + sin(s * 10.0) * 0.12
			n.set_meta("pose", "point")
			if randf() < d * 4.0:
				h.fx.burst(tp + Vector3(0, 0.2, 0), Color("7d5a38"), 4, 2.2, 0.45)
