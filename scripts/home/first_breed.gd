class_name FirstBreed
extends RefCounted
## The first-breeding prompt (briefs/design/GARDEN.md section 6; the gates are NookRules). The first time two
## Boki on the farm meet every Nook gate, one of them walks to the Nesting Nook, waits when you fall behind
## and looks back; when you come up, a centred card says what breeding is and shows the egg preview with one
## "Pair them" button. It never blocks, closes like any card, and shows once: Save.d.tutorial.first_breed.
## A save that has already bred is marked by the v13 -> v14 migration.
## Without a ready pair, the Nook's intro names the gate that is missing (missing_line).

const SEEN := "first_breed"      # Save.d.tutorial key: the card has been shown (or the Nook opened)
const POLL_SEC := 1.0            # s between looks for a ready pair
const LEAD_SEC := 90.0           # s a walk lasts before the Boki gives up (it tries again in RETRY_SEC)
const RETRY_SEC := 120.0         # s before a Boki that gave up leads again
const WAIT_GAP := 7.0            # m: the Boki stops and looks back when you are this far behind
const NEAR_NOOK := 4.5           # m: you are this close to the Nook, the card opens
const FRONT := Vector3(0, 0, 1.7)    # m: where the Boki waits, in front of the Nook
const CARD_W := 470.0            # px, the card's width
const BREED_LINE := "Two Grown Boki who are friends can leave an egg here. The baby takes after both."
## What stops the best pair, in the order the gates are checked (index = the stage a pair has reached).
const MISSING := [
	"Breeding needs two Grown Boki (level %d). Keep raising yours.",
	"Two Grown Boki also need to be friends. Play and nap together to build that.",
	"Your Grown friends are resting after their last egg. Try again soon.",
	"There's no room for a baby: your farm and the Burrow are full.",
]

var h                                   # the Home screen
var lead: Dictionary = {}               # the kin leading you to the Nook (home.kins entry)
var pair: Array = []                    # its pair: [a, b] (kin records)
var marker: Label3D = null
var look_t := 0.0                       # s until the next scan for a ready pair
var lead_t := 0.0                       # s this walk has lasted
var cool_t := 0.0                       # s until a Boki that gave up may lead again
var nag_t := 0.0                        # s until the leader calls out again

func _init(home) -> void:
	h = home

static func seen() -> bool:
	return bool(Save.d["tutorial"].get(SEEN, false))

## The first pair among these kin records that meets every gate ([] when none).
static func ready_pair(recs: Array) -> Array:
	for i in recs.size():
		for j in range(i + 1, recs.size()):
			if NookRules.pair_why(recs[i], recs[j]) == "":
				return [recs[i], recs[j]]
	return []

## The gate stopping the furthest-along pair, in one plain line ("" when a pair is ready).
static func missing_line(recs: Array) -> String:
	if not Save.d.get("egg", {}).is_empty():
		return "The nest has an egg in it. It takes one egg at a time."
	var best := 0
	for i in recs.size():
		for j in range(i + 1, recs.size()):
			best = maxi(best, _stage(recs[i], recs[j]))
	if best >= MISSING.size():
		return ""
	if best == 0:
		return MISSING[0] % NookRules.GROWN_LV
	return MISSING[best]

## How many gates this pair has passed: Grown, friends, rested, room for a baby.
static func _stage(a: Dictionary, b: Dictionary) -> int:
	if mini(int(a["level"]), int(b["level"])) < NookRules.GROWN_LV:
		return 0
	if not NookRules.friends(a, b):
		return 1
	if not (NookRules.rested(a) and NookRules.rested(b)):
		return 2
	return 3 if KinBox.full() else MISSING.size()

## The save moves to v14: a save that has already bred (an egg in the nest, or a kin with parents) never
## sees the prompt.
static func migrate(data: Dictionary) -> void:
	var bred: bool = not (data.get("egg", {}) as Dictionary).is_empty()
	for r in data.get("roster", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if not (r.get("parents", []) as Array).is_empty() or r.has("bred_m") or r.has("bred_t"):
			bred = true
	if bred and typeof(data.get("tutorial")) == TYPE_DICTIONARY:
		data["tutorial"][SEEN] = true

func tick(d: float) -> void:
	if not h.visit.is_empty() or seen():
		return
	if h.panel_open == "Nesting Nook":
		_finish()
		return
	cool_t = maxf(0.0, cool_t - d)
	if lead.is_empty():
		look_t -= d
		if look_t <= 0.0:
			look_t = POLL_SEC
			_try_start()
		return
	if h.panel_open != "":
		return
	_walk(d)

func _free(k: Dictionary) -> bool:
	return not (k.get("busy", false) or k.has("indoors") or k.has("leap") or k.has("job") or k.has("fetch")
			or k.has("bath") or float(k.get("nap_t", 0.0)) > 0.0 or k.has("called_t"))

func _try_start() -> void:
	if cool_t > 0.0 or h.panel_open != "" or h.NEST_AT.x < -100.0 or FarmTutorial.active():
		return
	var recs: Array = []
	for k in h.kins:
		if _free(k) and h.world.island_of(k["pos"].x, k["pos"].z) == h.world.island_of(h.NEST_AT.x, h.NEST_AT.z):
			recs.append(k["rec"])
	pair = ready_pair(recs)
	if pair.is_empty():
		return
	for k in h.kins:
		if is_same(k["rec"], pair[0]):
			lead = k
	lead_t = 0.0
	nag_t = 0.0
	h._say(lead, "Follow me! There's something I want to show you.", 3.5)

func _walk(d: float) -> void:
	if not is_instance_valid(lead["node"]) or not _free(lead):
		_stop(RETRY_SEC)
		return
	lead_t += d
	if lead_t > LEAD_SEC:
		_stop(RETRY_SEC)
		return
	lead["t"] = 3.0      # it keeps to this walk instead of picking its own goal
	lead.erase("chase")      # and does not run off after a friend in a game of tag
	var pos: Vector3 = lead["pos"]
	var spot: Vector3 = h.NEST_AT + FRONT
	if Vector2(h.ppos.x - h.NEST_AT.x, h.ppos.z - h.NEST_AT.z).length() < NEAR_NOOK:
		_show_card()
		return
	var behind := Vector2(h.ppos.x - pos.x, h.ppos.z - pos.z).length() > WAIT_GAP
	var arrived := Vector2(spot.x - pos.x, spot.z - pos.z).length() < 1.0
	lead["goal"] = pos if (behind or arrived) else spot      # waits, and (standing) turns to look back at you
	if behind or arrived:
		nag_t -= d
		if nag_t <= 0.0:
			nag_t = 4.0
			lead["joy_t"] = 0.9
			h._emote(lead, "!")
	_mark()

func _mark() -> void:
	if not is_instance_valid(marker):
		marker = Label3D.new()
		marker.font = UI.big
		marker.font_size = 56
		marker.pixel_size = 0.0095
		marker.outline_size = 16
		marker.modulate = UI.GOLD
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.no_depth_test = true
		h.add_child(marker)
	marker.text = "Nesting Nook\n▼"
	marker.position = h.NEST_AT + Vector3(0, 3.6 + sin(lead_t * 3.0) * 0.18, 0)

func _stop(retry: float) -> void:
	if not lead.is_empty():
		lead["t"] = 0.0
		lead["goal"] = Vector3.INF
	lead = {}
	cool_t = retry
	if is_instance_valid(marker):
		marker.queue_free()
	marker = null

## You opened the Nook yourself, or the card was shown: the prompt is done for good.
func _finish() -> void:
	Save.d["tutorial"][SEEN] = true
	Save.save_game()
	_stop(0.0)

func _show_card() -> void:
	var a: Dictionary = pair[0]
	var b: Dictionary = pair[1]
	_finish()
	var v: VBoxContainer = h._new_panel("Breeding", CARD_W)
	v.add_child(UI.para(BREED_LINE, UI.T_SMALL, UI.INK))
	v.add_child(UI.para("%s and %s are ready." % [a["name"], b["name"]], UI.T_SMALL, UI.GOOD))
	v.add_child(NookPreview.card(a, b, h.get_tree()))
	UI.footer_primary(v, "Pair them", func(): h._make_egg(a, b), 200, "egg")
