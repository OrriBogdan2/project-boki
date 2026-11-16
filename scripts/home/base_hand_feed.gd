class_name BaseHandFeed
extends RefCounted
## Feeding from your hand (base_mode only): pick a snack with the glove key (Q, which does nothing at home), then
## hold the use key near a Boki. One with enough trust walks over and eats from your hand; a shy one (trust under
## the whistle's shy_trust) walks half way and stops, and only comes the whole way if you ask again within
## shy_window_s; a full one, or one that hates it, comes, sniffs and leaves. The meal is Care.feed, so the snack's
## own effect (joy, lean, journal) is the same as at the bowl or the Feed menu; only the walk is new. BaseLife owns
## the states (Approach, HandEat, Done), this file the rules around them. Tuning: base_life.json "hand".

var h                       # the home (home.gd)
var R: Dictionary           # base_life.json "hand"
var shy_trust: float        # base_life.json whistle.shy_trust: under it a Boki is shy of your hand
var snack := ""             # the selected snack ("" for none)

func _init(home, rules: Dictionary) -> void:
	h = home
	R = rules["hand"]
	shy_trust = float(rules["whistle"]["shy_trust"])

## The prompt text (the use key is held, not tapped).
static func hint() -> String:
	return "Hold %s to feed" % Settings.key_cap("interact")

## Snacks in the pantry that go in a hand: the stall foods and the crops, as the Feed menu lists them.
static func options() -> Array:
	var out: Array = []
	for f in Care.FOODS:
		if Econ.pantry(String(f)) > 0 and not GardenItems.has(String(f)):
			out.append(String(f))
	for f in Data.CROPS:
		if Econ.pantry(String(f)) > 0:
			out.append(String(f))
	return out

## The glove key: the next snack in the pantry, then none.
func cycle() -> void:
	var all := options()
	var next := all.find(snack) + 1
	snack = String(all[next]) if next < all.size() else ""
	Sfx.play("click")

## The prompt's key hints with the selected snack: the held use key feeds instead of picking the Boki up.
func pairs(base: Array) -> Array:
	if snack != "" and Econ.pantry(snack) <= 0:
		snack = ""
	if snack == "":
		return base
	var out := base.filter(func(p): return not String(p[0]).ends_with(" hold"))
	out.append([Settings.key_cap("gear1"), "%s %s" % [hint(), Care.food_name(snack)]])
	return out

## The use key was held on `k`: true when the hand-feed took it (false: pick it up as before).
func offer(k: Dictionary) -> bool:
	if snack == "":
		return false
	var m: Fsm = h.life.machine(k)
	if m.is_in(BaseLife.S.APPROACH) or m.is_in(BaseLife.S.HAND_EAT) or m.is_in(BaseLife.S.DONE):
		return true
	if not m.go(BaseLife.S.APPROACH, "hand"):
		return false
	var asked := _now() - float(k.get("hand_shy", -1.0e9)) < float(R["shy_window_s"])
	k["hand"] = {"food": snack, "shy": float(k["rec"]["trust"]) < shy_trust and not asked, "res": {}, "bit": null}
	return true

## Approach: walks to a spot by your hand; there it is shy, or eats, or sniffs.
func approach(k: Dictionary, m: Fsm) -> void:
	var e: Dictionary = k["hand"]
	var to := Vector2(h.ppos.x - k["pos"].x, h.ppos.z - k["pos"].z)
	var stop := float(R["shy_stop_m"] if e["shy"] else R["slot_m"])
	k["goal"] = h.ppos - Vector3(to.x, 0, to.y).normalized() * stop
	if to.length() > stop + float(R["arrive_m"]):
		if m.since >= float(R["give_up_s"]):
			m.go(BaseLife.S.DONE, "gave up")
		return
	_face(k)
	k["goal"] = k["pos"]
	if e["shy"]:
		k["hand_shy"] = _now()
		h._emote(k, "…")
		m.go(BaseLife.S.DONE, "shy")
		return
	var food := String(e["food"])
	var rec: Dictionary = k["rec"]
	var res: Dictionary = Care.feed(rec, food) if Econ.pantry(food) > 0 else {}
	if res.is_empty() or not res["ok"]:
		if res.is_empty():
			h._emote(k, "?")
		else:
			h._after_feed(k, food, res)      # a sniff, and its line: full, or it won't eat that
		m.go(BaseLife.S.DONE, "sniffed")
		return
	Econ._take_pantry(food)      # the snack leaves the pantry once, here
	rec["trust"] = clampf(float(rec["trust"]) + float(R["trust"]), 0.0, 100.0)
	e["res"] = res
	e["bit"] = _bit(k, food)
	m.go(BaseLife.S.HAND_EAT, "eats")

## HandEat: a short beat at your hand, then the usual reaction to a meal (joy, lean, a line, a toast).
func eat(k: Dictionary, m: Fsm) -> void:
	_face(k)
	if m.since < float(R["eat_s"]):
		return
	var e: Dictionary = k["hand"]
	m.go(BaseLife.S.DONE, "ate")
	h._after_feed(k, String(e["food"]), e["res"])
	GardenFirstDay.mark("feed", h)
	GardenVisitor.fed(h, k["rec"], e["res"])

## Done: a moment to enjoy it (or turn away), then back to its day.
func done(m: Fsm) -> void:
	if m.since >= float(R["done_s"]):
		m.go(BaseLife.S.ROAM, "fed")

## Leaving Done: the bite is gone, the hand is empty.
static func clear(k: Dictionary) -> void:
	var e: Dictionary = k.get("hand", {})
	if e.get("bit") != null and is_instance_valid(e["bit"]):
		(e["bit"] as Node).queue_free()
	k.erase("hand")

func _bit(k: Dictionary, food: String) -> MeshInstance3D:
	var bit := MeshInstance3D.new()
	bit.mesh = Models.sphere(0.11, 10)
	bit.material_override = Models.toon(Care.food_col(food))
	bit.position = k["pos"].lerp(h.ppos, 0.5) + Vector3(0, 0.45, 0)
	h.add_child(bit)
	return bit

func _face(k: Dictionary) -> void:
	(k["node"] as Node3D).rotation.y = atan2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z)

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
