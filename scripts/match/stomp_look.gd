class_name StompLook
extends RefCounted
## How a stomp looks: the stomp styles in content/rules/stomps.json and the "stomp" cosmetic slot.
## Each Hunter has its own default style (always owned); other styles are bought with gems and worn
## in the slot (Save.d["look"]["stomp"], "" = your Hunter's own). A style only changes the body:
## every style keeps Stomp's timing. HunterAnim blends the pose below in while a stomp runs.
## Old saves have neither key; both read as "nothing bought, wearing your own".

const RULES_PATH := "res://content/rules/stomps.json"

static var _rules := {}
static var _styles := {}      # id -> the style with every key filled in from "base"

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		var base: Dictionary = _rules["base"]
		for id in _rules["styles"]:
			var full := base.duplicate()
			full.merge(_rules["styles"][id], true)
			_styles[id] = full
		_styles[""] = base
	return _rules

## A style with every key filled in; "" or an unknown id gives the base stomp.
static func style(id: String) -> Dictionary:
	rules()
	return _styles.get(id, _styles[""])

## The style a Hunter's own stomp uses ("" if the data has none for its archetype).
static func default_for(arch: String) -> String:
	for id in rules()["styles"]:
		if String(rules()["styles"][id].get("hunter", "")) == arch:
			return id
	return ""

## The style this Hunter stomps with: the local player's worn one, else its Hunter's own.
static func style_id(h: Hunter) -> String:
	var worn := equipped()
	return worn if h.is_local() and worn != "" else default_for(h.arch)

static func owned(id: String) -> bool:
	if not (rules()["styles"] as Dictionary).has(id):
		return false
	return rules()["styles"][id].has("hunter") or (Save.d.get("stomps", []) as Array).has(id)

## The worn style id, "" for your Hunter's own.
static func equipped() -> String:
	var id := String(Save.d.get("look", {}).get("stomp", ""))
	return id if owned(id) else ""

## Wear an owned style from now on ("" goes back to your Hunter's own). False if you don't own it.
static func equip(id: String) -> bool:
	if id != "" and not owned(id):
		return false
	if not Save.d.has("look"):
		Save.d["look"] = Unmasked.default_look()
	Save.d["look"]["stomp"] = id
	return true

## Buy a style with gems. False if it isn't for sale, already yours, or you can't afford it.
static func buy(id: String) -> bool:
	var cost := int(rules()["styles"].get(id, {}).get("cost", -1))
	if cost < 0 or owned(id) or int(Save.d.get("gems", 0)) < cost:
		return false
	Save.d["gems"] = int(Save.d["gems"]) - cost
	if not Save.d.has("stomps"):
		Save.d["stomps"] = []
	Save.d["stomps"].append(id)
	return true

# ------------------------------------------------------------------ the pose
## How far the lifted foot is up at a beat phase (0..1): up and back down by Stomp.SLAM.
static func _up(beat: float) -> float:
	var ph := fposmod(beat, 1.0)
	return sin(ph / Stomp.SLAM * PI) if ph < Stomp.SLAM else 0.0

## Leg angles, Vector4(hip_l, knee_l, hip_r, knee_r), at a beat (Stomp.beat: 0..BEATS).
static func legs(st: Dictionary, beat: float) -> Vector4:
	var up := _up(beat)
	var crouch := float(st["crouch"])
	if st["foot"] == "both":
		var hip := 0.5 * float(st["lift"]) * up + crouch * 0.6 + 0.1
		var knee := 0.6 * float(st["knee"]) * up - 0.2 - crouch * 0.9
		return Vector4(hip, knee, hip, knee)
	var lift_hip := float(st["lift"]) * up - 0.05
	var lift_knee := float(st["knee"]) * up - 0.1
	var stand_hip := 0.2 + crouch * 0.6
	var stand_knee := -0.4 - crouch * 0.9
	var right: bool = st["foot"] == "r" or (st["foot"] == "alt" and int(beat) % 2 == 0)
	if right:
		return Vector4(stand_hip, stand_knee, lift_hip, lift_knee)
	return Vector4(lift_hip, lift_knee, stand_hip, stand_knee)

## The body: Vector3(forward lean, shoulder turn, rise in metres).
static func body(st: Dictionary, beat: float) -> Vector3:
	var up := _up(beat)
	var crouch := float(st["crouch"])
	return Vector3(float(st["lean"]) + crouch * 0.1, float(st["twist"]) * up, float(st["hop"]) * up - crouch * 0.12)

## Whether a style needs both hands (the weapon is put away for it).
static func two_handed(st: Dictionary) -> bool:
	return not String(st["arms"]) in ["out", "weapon"]

## Where a hand goes, from its shoulder (side -1 left, 1 right); Vector3.INF leaves it be.
static func hand(st: Dictionary, beat: float, sh: Vector3, side: float) -> Vector3:
	var up := _up(beat)
	var off := Vector3.INF
	match String(st["arms"]):
		"out": if side < 0.0: off = Vector3(-0.32, -0.15, -0.05)
		"wide": off = Vector3(-0.32, -0.15, -0.05)
		"up": off = Vector3(-0.1, -0.3, -0.3).lerp(Vector3(-0.05, 0.42, -0.1), up)
		"fists": off = Vector3(-0.12, -0.6, -0.4).lerp(Vector3(-0.1, 0.1, -0.25), up)
		"hips": off = Vector3(-0.14, -0.42, 0.06)
	if off == Vector3.INF:
		return off
	return sh + Vector3(off.x * -side, off.y, off.z)
