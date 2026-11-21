class_name StompLook
extends RefCounted
## How a stomp looks: the styles in content/rules/stomps.json and the "stomp" cosmetic slot
## (docs/decisions/0062-stomp-styles.md). A Hunter with a stomp clip stomps with it; a rig without one
## uses its Hunter's own style ("hunter" in the data) or the base stomp. A style bought with gems and
## worn (Save.d["look"]["stomp"], "" = your Hunter's own) plays on the rig instead, for your Hunter only:
## the wire carries no style, so other games show a remote stomper's own stomp. Old saves have neither
## key; both read as "nothing bought, wearing your own" (no migration). Timing stays Life's.

const RULES_PATH := "res://content/rules/stomps.json"
const SLAM := 0.7      # the part of a stomp cycle the foot is up and coming down (Life.R stomp_cycle)

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

## The style a Hunter's own stomp uses on a rig without a clip ("" = the base stomp).
static func default_for(arch: String) -> String:
	for id in rules()["styles"]:
		if String(rules()["styles"][id].get("hunter", "")) == arch:
			return id
	return ""

static func for_sale(id: String) -> bool:
	return (rules()["styles"] as Dictionary).has(id) and rules()["styles"][id].has("cost")

static func owned(id: String) -> bool:
	return for_sale(id) and (Save.d.get("stomps", []) as Array).has(id)

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

## The anim state of a stomp: "stomp" (the cycle's phase, -1 off), "stomp_n" (which cycle), "stomp_style"
## and "stomp_own" (false: a worn style, so a Hunter's stomp clip gives way to the rig's pose).
static func fill(h: Hunter, s: Dictionary) -> void:
	if h.stomp.is_empty():
		s["stomp"] = -1.0
		return
	var t := float(h.stomp["t"])
	var cyc: float = Life.R["stomp_cycle"]
	s["stomp"] = fmod(t, cyc) / cyc
	s["stomp_n"] = int(t / cyc)
	var worn := equipped() if h.is_local() else ""
	s["stomp_style"] = worn if worn != "" else default_for(h.arch)
	s["stomp_own"] = worn == ""

# ------------------------------------------------------------------ the pose
## How far the lifted foot is up at a cycle phase (0..1): up and back down by SLAM.
static func up(ph: float) -> float:
	return sin(clampf(ph, 0.0, 1.0) / SLAM * PI) if ph < SLAM else 0.0

## Leg angles, Vector4(hip_l, knee_l, hip_r, knee_r), at a cycle phase of cycle n.
static func legs(st: Dictionary, ph: float, n: int) -> Vector4:
	var u := up(ph)
	var crouch := float(st["crouch"])
	if st["foot"] == "both":
		var hip := 0.5 * float(st["lift"]) * u + crouch * 0.6 + 0.1
		var knee := 0.6 * float(st["knee"]) * u - 0.2 - crouch * 0.9
		return Vector4(hip, knee, hip, knee)
	var lift := Vector2(float(st["lift"]) * u - 0.05, float(st["knee"]) * u - 0.1)
	var stand := Vector2(0.2 + crouch * 0.6, -0.4 - crouch * 0.9)
	if st["foot"] == "r" or (st["foot"] == "alt" and n % 2 == 0):
		return Vector4(stand.x, stand.y, lift.x, lift.y)
	return Vector4(lift.x, lift.y, stand.x, stand.y)

## The body: Vector3(forward lean, shoulder turn, rise in metres).
static func body(st: Dictionary, ph: float) -> Vector3:
	var u := up(ph)
	var crouch := float(st["crouch"])
	return Vector3(float(st["lean"]) + crouch * 0.1, float(st["twist"]) * u, float(st["hop"]) * u - crouch * 0.12)

## Where a hand goes from its shoulder (side -1 left, 1 right); Vector3.INF leaves it on the weapon.
static func hand(st: Dictionary, ph: float, sh: Vector3, side: float) -> Vector3:
	var u := up(ph)
	var off := Vector3.INF
	match String(st["arms"]):
		"out":
			if side < 0.0:
				off = Vector3(-0.32, -0.15, -0.05)
		"wide": off = Vector3(-0.32, -0.15, -0.05)
		"up": off = Vector3(-0.1, -0.3, -0.3).lerp(Vector3(-0.05, 0.42, -0.1), u)
		"fists": off = Vector3(-0.12, -0.6, -0.4).lerp(Vector3(-0.1, 0.1, -0.25), u)
		"hips": off = Vector3(-0.14, -0.42, 0.06)
	if off == Vector3.INF:
		return off
	return sh + Vector3(off.x * -side, off.y, off.z)
