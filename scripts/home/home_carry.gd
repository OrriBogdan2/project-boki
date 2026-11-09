class_name HomeCarry
extends RefCounted
## Raising and bonding at home: hold interact on a Boki to pick it up and put it somewhere, press interact to set it
## down. A small Boki rides in both arms, a middling one on your back, and a big one stays on the ground and follows
## beside you (hold again to let go). You walk at SPEED_K while you carry or lead. It reacts to its traits: a brave one
## wriggles happily, a timid one clings, a grumpy one squirms free after SQUIRM_S. Carrying a Close-or-better bond
## for TRUST_S adds a little trust, once a day. Home only (never in a match). A tap on a Boki is still a pat.
## home.gd calls tick() each frame, speed_mul() in its walk speed and anim_state() for the hunter's pose.

const HOLD_S := 0.45          # s the interact key is held on a Boki to pick it up (a shorter press pats)
const ARMS_KG := 3.5          # up to this weight it rides in your arms
const BACK_KG := 9.0          # up to this weight it rides on your back; heavier ones are led
const SPEED_K := 0.9          # share of your walking speed while carrying or leading
const SQUIRM_S := 5.0         # s a grumpy Boki lets itself be carried before it wriggles free
const TRUST_S := 3.0          # s carried before the daily trust counts
const TRUST_GAIN := 1.0       # trust a bonded Boki gains from its first carry of the day
const BOND_MIN := 2           # Care.bond_index needed for that trust (2 = Close)
const BRAVE := 0.62           # bravery above this wriggles happily
const TIMID := 0.4            # bravery below this clings
const GRUMPY := 0.62          # temper above this squirms free
const CARRY_SCALE := 0.7      # a carried Boki is shown this share of its size, so it fits the arms
const DROP_DIST := 0.9        # m in front of you where it is set down
const LEAD_SLOT := 0.9        # m to your right where a led Boki walks
const LEAD_MAX := 10.0        # m away at which a led Boki is let go

var h                         # the Home screen
var k := {}                   # the Boki in your arms, on your back or on its lead
var mode := ""                # "carry" (arms), "pack" (back) or "lead"
var t := 0.0                  # s since it was picked up
var paid := false             # today's trust already counted for this carry
var pending := {}             # the Boki the key is held on, waiting to pass HOLD_S
var held := 0.0               # s the key has been held on it
var base_scale := Vector3.ONE

func _init(home) -> void:
	h = home

## "arms", "back" or "lead": how a Boki of this weight travels with you.
static func mode_for(rec: Dictionary) -> String:
	var kg := float(Unique.size_info(rec)["kg"])
	if kg <= ARMS_KG:
		return "carry"
	return "pack" if kg <= BACK_KG else "lead"

## "grumpy", "brave", "timid" or "calm": which way it reacts to being held.
static func temper_of(rec: Dictionary) -> String:
	var tr: Dictionary = rec["traits"]
	if float(tr.get("temper", 0.5)) > GRUMPY:
		return "grumpy"
	var bravery := float(tr.get("bravery", 0.5))
	if bravery > BRAVE:
		return "brave"
	return "timid" if bravery < TIMID else "calm"

func carrying() -> bool:
	return mode == "carry" or mode == "pack"

func speed_mul() -> float:
	return SPEED_K if not k.is_empty() else 1.0

func anim_state() -> Dictionary:
	return {"act": mode} if carrying() else {}

## Called every frame from home.gd; true when it used the interact key press.
func tick(d: float, interact: Dictionary, can: bool) -> bool:
	if not k.is_empty():
		_step(d)
	if not can or not h.visit.is_empty():
		pending = {}
		return false
	var pressed := Input.is_action_just_pressed("interact")
	if carrying():
		if pressed:
			drop()
		return pressed
	if pressed and interact.get("kind", "") == "kin":
		pending = interact["k"]
		held = 0.0
		return true
	if pending.is_empty():
		return false
	if Input.is_action_pressed("interact"):
		held += d
		if held >= HOLD_S:
			var who: Dictionary = pending
			pending = {}
			press_hold(who)
		return true
	h._use({"kind": "kin", "k": pending})
	pending = {}
	return true

## The held key reached HOLD_S on a Boki: pick it up, lead it, or let it go.
func press_hold(who: Dictionary) -> void:
	if who == k:
		_let_go(who, h.ppos)
		return
	if not k.is_empty() or who.get("busy", false) or who.has("fetch") or who.has("bath") or who.has("leap"):
		return
	k = who
	mode = mode_for(who["rec"])
	t = 0.0
	paid = false
	who["nap_t"] = 0.0
	who.erase("chase")
	who.erase("task")
	who.erase("called_t")
	who.erase("going_in")
	if mode == "lead":
		who["led"] = true
		h._emote(who, "♥", true)
		return
	who["busy"] = true
	var n: Node3D = who["node"]
	base_scale = n.scale
	h._emote(who, "★" if temper_of(who["rec"]) == "brave" else "♥", true)
	Sfx.play("kin_happy", null, -6.0, 0.12, Unique.voice(who["rec"]))

## Press while carrying: set it down in front of you (or at your feet if that spot is blocked).
func drop() -> void:
	var fwd := _forward()
	var at: Vector3 = h.ppos + fwd * DROP_DIST
	if h.world.occupy(at.x, at.z, 0.3, 0.0, true) != 0.0 or h.world.is_void(at.x, at.z):
		at = h.ppos
	_let_go(k, at)

func _forward() -> Vector3:
	return Vector3(-sin(h.pface), 0.0, -cos(h.pface))

## It is on the ground again at `at` and goes back to being itself.
func _let_go(who: Dictionary, at: Vector3) -> void:
	var n: Node3D = who["node"]
	if mode != "lead":
		who["pos"] = Vector3(at.x, who["pos"].y, at.z)
		n.position = who["pos"]
		n.scale = base_scale
		n.rotation.z = 0.0
		who["busy"] = false
		who["hold_t"] = 1.0
		who["goal"] = who["pos"]
	who.erase("led")
	who["t"] = 1.5
	k = {}
	mode = ""

func _step(d: float) -> void:
	t += d
	var rec: Dictionary = k["rec"]
	if mode == "lead":
		_lead()
		return
	var feel := temper_of(rec)
	if feel == "grumpy" and t >= SQUIRM_S:
		_squirm_free()
		return
	_pay(rec)
	var n: Node3D = k["node"]
	var s: float = h.player.scale.x
	var fwd := _forward()
	var off := fwd * 0.42 + Vector3(0, 0.85, 0)
	if mode == "pack":
		off = fwd * -0.34 + Vector3(0, 1.05, 0)
	var wob := 0.0
	match feel:
		"brave":
			wob = sin(t * 9.0) * 0.2
			off.y += absf(sin(t * 9.0)) * 0.05
		"timid":
			off = off * Vector3(0.6, 1.0, 0.6)
			wob = sin(t * 24.0) * 0.03
		"grumpy":
			wob = sin(t * 20.0) * 0.5 * (t / SQUIRM_S)
		_:
			wob = sin(t * 2.0) * 0.05
	var at: Vector3 = h.player.position + off * s
	k["pos"] = Vector3(at.x, k["pos"].y, at.z)
	n.position = at
	n.scale = base_scale * CARRY_SCALE
	n.rotation = Vector3(0.0, h.pface + (PI if mode == "pack" else 0.0), wob)

## The first carry of the day, held long enough, brings a bonded Boki a little closer.
func _pay(rec: Dictionary) -> void:
	if paid or t < TRUST_S:
		return
	paid = true
	var today := Time.get_datetime_dict_from_system()
	var day := "%d-%02d-%02d" % [today["year"], today["month"], today["day"]]
	if Care.bond_index(rec) < BOND_MIN or String(rec.get("carried_day", "")) == day:
		return
	rec["carried_day"] = day
	Save.remember(rec, "carried", "was carried around the farm in your arms", TRUST_GAIN)
	Save.save_game()

## A grumpy Boki has had enough: it jumps down and stalks off.
func _squirm_free() -> void:
	var who := k
	var away: Vector3 = h.ppos + _forward() * DROP_DIST
	_let_go(who, away)
	who["hold_t"] = 0.0
	who["goal"] = who["pos"] + _forward() * 3.0
	h._emote(who, "!", true)
	Sfx.play("thump", who["pos"], -12.0, 0.1, 1.3)

## A big Boki follows beside you; far behind, it's let go.
func _lead() -> void:
	var dist := Vector2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z).length()
	if dist > LEAD_MAX:
		h._emote(k, "?", true)
		_let_go(k, k["pos"])
		return
	var side := Vector3(-_forward().z, 0.0, _forward().x)
	k["goal"] = h.ppos + side * LEAD_SLOT - _forward() * 0.3
	k["t"] = 1.0
	k["hold_t"] = 0.0
