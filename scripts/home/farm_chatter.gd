class_name FarmChatter
extends RefCounted
## Boki at home talk about what's going on around them (BokiLines triggers): a crop ready or just
## watered beside them, the job they're doing or the building going up, rain, night, what they need,
## a friend close by (the friend answers), and news (a new Boki, you back with loot: ComeLook).
## Every few seconds one Boki near you may speak up; Home._say keeps it to one voice at a time and
## BokiLines to a cooldown each.

const LOOK_S := 2.5          # s between looks for something to talk about
const SPEAK_CHANCE := 0.4    # share of looks where a Boki speaks up
const SEEN_R := 11.0         # m: only Boki this close to you chat (you can see them)
const CROP_R := 2.6          # m: a crop this close is the one it's looking at
const FRIEND_R := 2.4        # m: two Boki this close are together
const WATERED_S := 15.0      # s: a plant watered this recently is still news
const NIGHT_SUN := -0.15     # sun height (-1..1) below which it's night (as the music decides)
const REPLY_GAP_S := 0.3     # s between one Boki's bubble ending and its friend's answer

static var _look_t := 0.0
static var _known := {}      # uid -> true: Boki that were already home (a new uid is an arrival)

## Called every frame by Home: now and then, one Boki says something about what's around it.
static func tick(h, d: float) -> void:
	ComeLook.tick(h, d)
	_look_t -= d
	if _look_t > 0.0:
		return
	_look_t = LOOK_S
	if not h.visit.is_empty() or h.panel_open != "" or h.chat_open:
		return
	_welcome(h)
	var idle := (h.kins as Array).filter(func(k): return _idle(h, k))
	if idle.is_empty() or randf() > SPEAK_CHANCE:
		return
	var k: Dictionary = idle.pick_random()
	var friend := _friend_near(idle, k)
	var options := _triggers(h, k)
	if not friend.is_empty():
		options.append("chat")
	if options.is_empty():
		return
	var topic := String(options.pick_random())
	h._say(k, BokiLines.say(k["rec"], topic), 0.0, false)
	if topic == "chat" and float(k.get("say_t", 0.0)) > 0.0:
		_answer_later(h, friend)

## What's going on around it that it could talk about (none: it stays quiet).
static func _triggers(h, k: Dictionary) -> Array:
	var out: Array = []
	if k.has("job"):
		out.append("building" if String(k["job"].get("kind", "")) == "build" else "working")
	out.append_array(_crop_news(h, k["pos"]))
	if h.raining:
		out.append("rain")
	if sin((float(h.day_t) - 0.25) * TAU) < NIGHT_SUN:
		out.append("night")
	var want := Care.want(k["rec"])
	if want != "":
		out.append("want_" + want)
	return out

## crop_ready / crop_watered for a planted plot beside this spot.
static func _crop_news(h, at: Vector3) -> Array:
	var out: Array = []
	var now := Time.get_unix_time_from_system()
	for arr in ["plots", "gh_plots"]:
		var nodes: Array = h.plots if arr == "plots" else h.gh_plots
		for i in mini(nodes.size(), (Save.d[arr] as Array).size()):
			var pd: Dictionary = Save.d[arr][i]
			if pd["crop"] == "" or (nodes[i] as Node3D).position.distance_to(at) > CROP_R:
				continue
			if int(pd["stage"]) >= int(Data.CROPS[pd["crop"]]["grow"]):
				out.append("crop_ready")
			elif float(pd.get("wt", 0.0)) > 0.0 and now - float(pd["wt"]) < WATERED_S:
				out.append("crop_watered")
	return out

## A Boki that isn't napping, bathing, playing, busy with you or far off.
static func _idle(h, k: Dictionary) -> bool:
	if k.get("busy", false) or k.has("fetch") or k.has("bath") or k.has("indoors"):
		return false
	if float(k.get("nap_t", 0.0)) > 0.0 or float(k.get("say_t", 0.0)) > 0.0:
		return false
	var p: Vector3 = k["pos"]
	return Vector2(p.x - h.ppos.x, p.z - h.ppos.z).length() < SEEN_R

## Another idle Boki close to this one, or {}.
static func _friend_near(idle: Array, k: Dictionary) -> Dictionary:
	for o in idle:
		if o != k and (o["pos"] as Vector3).distance_to(k["pos"]) < FRIEND_R:
			return o
	return {}

## The friend answers once the first bubble is gone, so the two lines read as a little exchange.
static func _answer_later(h, friend: Dictionary) -> void:
	var timer: SceneTreeTimer = h.get_tree().create_timer(BokiLines.bubble_s() + REPLY_GAP_S)
	timer.timeout.connect(func():
		if is_instance_valid(h) and h.kins.has(friend) and _idle(h, friend):
			h.talk_cd = 0.0
			h._say(friend, BokiLines.say(friend["rec"], "chat_reply"), 0.0, false))

## A new Boki home (hatched, caught, bought) or you back with loot: nearby Boki come to look (ComeLook).
static func _welcome(h) -> void:
	var first := _known.is_empty()
	var arrived: Array = []
	for k in h.kins:
		var uid := String(k["rec"]["uid"])
		if not _known.has(uid):
			_known[uid] = true
			arrived.append(k)
	ComeLook.loot_home(h)
	if first or arrived.is_empty():
		return
	ComeLook.event(h, ComeLook.arrival_kind(arrived[0]["rec"]), arrived[0]["pos"], arrived[0])

## One Boki reacts to the news with a line for its trigger; false while someone nearby is still talking.
static func react(h, k: Dictionary, topic: String) -> bool:
	h.talk_cd = 0.0
	h._say(k, BokiLines.say(k["rec"], topic), 0.0, false)
	return float(k.get("say_t", 0.0)) > 0.0
