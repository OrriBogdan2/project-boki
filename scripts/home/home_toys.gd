class_name HomeToys
extends RefCounted
## The Boki base's playthings (content/rules/toys.json, GARDEN.md section 4): a ball, a climbing post, a
## splash tub, a warm stone and a dig patch, placed in build mode and used on their own. Only while
## farm_build.json base_mode is on.
## An idle Boki with room to be happier picks a toy by its lean and traits (a Flying or Rock Boki likes
## the post, Water and Ice the tub, Fire the stone, Grass and Bug the patch), walks to it, plays, and gains
## the toy's stat through Care.add_stat.
## A second Boki may join the first; two hot tempers squabble and the newcomer huffs off.
## k["play"] = {u: toy uid, phase: "go" | "play", t: seconds}. home.gd calls pick, step and pose.

const SPOT_R := 1.15          # tiles from a toy's centre to where a Boki stands
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

func _toy(u: int) -> Dictionary:
	for t in toys():
		if int(t["u"]) == u:
			return t
	return {}

## Who has committed to a toy (walking to it or playing), in the order they chose it.
func players(u: int) -> Array:
	return h.kins.filter(func(o): return o.has("play") and int(o["play"]["u"]) == u)

func _lean(rec: Dictionary) -> String:
	return String(rec.get("lean", BokiLines.element_of(String(rec.get("species", ""))))).to_lower()

## How much a Boki fancies a toy: its trait for that toy, and double the lean the toy is made for.
func weight(rec: Dictionary, toy_id: String) -> float:
	var R := rules()
	var def: Dictionary = R["toys"][toy_id]
	var w := 1.0 + float(R["trait_weight"]) * float(rec["traits"].get(String(def["trait"]), 0.5))
	if (def["likes"] as Array).has(_lean(rec)):
		w += float(R["like_weight"])
	return w

## An idle Boki looks for a toy: true when it has set off for one.
func pick(k: Dictionary) -> bool:
	var R := rules()
	var rec: Dictionary = k["rec"]
	if not FarmUnlocks.base_mode() or not h.visit.is_empty() or k.has("play"):
		return k.has("play")
	if Care.need(rec, "joy") >= float(R["joy_below"]) or randf() > float(R["pick_chance"]):
		return false
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	var weights := {}
	var total := 0.0
	for t in toys():
		var tp: Vector3 = t["pos"]
		if h.world.island_of(tp.x, tp.z) != here or players(int(t["u"])).size() >= int(R["max_players"]):
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
	var tp: Vector3 = t["pos"]
	var a := 0.8 + float(k["play"]["slot"]) * PI
	var p := tp + Vector3(cos(a), 0, sin(a)) * SPOT_R
	if h.world.is_void(p.x, p.z) or h.world.occupy(p.x, p.z, 0.3, 0.0, true) != 0.0:
		return h.world.free_spot_near(p, [], 1.0)
	return p

## Per frame, from home.gd's _care_step: walk to the toy, play, finish. True while it owns the Boki.
func step(k: Dictionary, d: float) -> bool:
	if not k.has("play"):
		return false
	var p: Dictionary = k["play"]
	var t := _toy(int(p["u"]))
	if t.is_empty() or not FarmUnlocks.base_mode() or _busy(k):
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
		_stop(k)
		k["t"] = float(R["sulk_secs"])
		return
	p["phase"] = "play"
	var secs: Array = R["play_secs"]
	p["t"] = randf_range(float(secs[0]), float(secs[1]))
	if others.size() >= 1:
		h._emote(k, "★", true)

func _temper(k: Dictionary) -> float:
	return float(k["rec"]["traits"].get("temper", 0.5))

func _finish(k: Dictionary, t: Dictionary) -> void:
	var R := rules()
	var rec: Dictionary = k["rec"]
	var def: Dictionary = R["toys"][t["id"]]
	var stat := String(def["stat"])
	var gained := Care.add_stat(rec, stat, int(R["stat_gain"]))
	Care.change(rec, "joy", float(R["joy_gain"]))
	if randf() < float(def.get("snack", 0.0)):
		var item := String(R["snack_item"])
		Save.add_item(item, 1)
		h._toast("%s dug up a %s" % [rec["name"], String(Care.FOODS[item]["name"]).to_lower()])
	h._emote(k, "♥" if gained > 0 else "♪", true)
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
			body.position.y = hop * 0.3
			body.rotation.x = -0.25 * sin(s * 3.0)
			n.set_meta("pose", "nudge")
			var ball := _ball(int(t["u"]))
			if ball:
				ball.position = Vector3(sin(s * 3.0) * 0.4, BALL_R + absf(sin(s * 6.0 + 1.0)) * 0.3, cos(s * 3.0) * 0.4)
		"toy_post":
			var climb := 0.5 - 0.5 * cos(fposmod(s * 0.9, TAU))
			body.position.y = climb * 0.9
			body.position.z = -0.35
			body.rotation.x = -0.5
			n.set_meta("pose", "alert" if climb > 0.8 else "")
		"toy_tub":
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
		"toy_dig":
			body.position.y = absf(sin(s * 10.0)) * 0.05
			body.rotation.x = -0.45 + sin(s * 10.0) * 0.12
			n.set_meta("pose", "point")
			if randf() < d * 4.0:
				h.fx.burst(tp + Vector3(0, 0.2, 0), Color("7d5a38"), 4, 2.2, 0.45)
