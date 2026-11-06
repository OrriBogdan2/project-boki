class_name HunterTool
extends RefCounted
## The tools a Hunter (or the Empty) works with at home: an axe to chop, a pickaxe to mine, a hammer
## to build. While one is out the weapon is put away (HunterAnim stows the gun, the off-hand blade,
## the shield and the mage's orb) and the tool is held in the hands. Each swing is a loop of
## raise, strike and settle; the strike lands at IMPACT of the swing, and the game lands its hit
## (a chip, a sound, a swing of labour) at the same moment.
##
## HunterAnim state keys: "tool" ("axe" | "pickaxe" | "hammer" | ""), "tool_t" (seconds into the
## current swing), "act" (the pose, one of ACTS) and "holster" (the weapon stays put away: the
## Empty at home carries no class weapon).

## What each tool does: the pose it plays, seconds per swing, how high it is lifted (1 = overhead),
## the haft length (m) and whether it takes both hands.
const TOOLS := {
	"axe": {"act": "chop", "period": 1.0, "lift": 1.0, "haft": 0.62, "two_hands": true},
	"pickaxe": {"act": "mine", "period": 0.9, "lift": 0.9, "haft": 0.62, "two_hands": true},
	"hammer": {"act": "build", "period": 0.8, "lift": 0.55, "haft": 0.4, "two_hands": false},
}
const ACTS := ["chop", "mine", "build"]
const IMPACT := 0.78          # share of a swing at which the head meets the target
const WIND := 0.5             # share of a swing spent lifting the tool before the strike
const RECOIL := 0.12          # how far the tool bounces back up after the strike (share of the lift)
const GRIP_GAP := 0.2         # m between the two hands on a haft
const SIZE := 1.4            # the tool is drawn this much larger than life so it reads at the farm camera
const POP_RATE := 12.0        # how fast the tool and the stowed weapon fade (per second)
const DIR_HIT := Vector3(0.0, -0.35, -1.0)
const DIR_LIFT := Vector3(0.0, 0.8, -0.7)
const HAMMER_DIR_HIT := Vector3(0.0, -0.25, -1.0)
const HAMMER_DIR_LIFT := Vector3(0.0, 0.9, -0.5)

static func period(tool: String) -> float:
	return float(TOOLS[tool]["period"])

static func act_of(tool: String) -> String:
	return String(TOOLS[tool]["act"]) if TOOLS.has(tool) else ""

static func tool_of_act(act: String) -> String:
	for t in TOOLS:
		if TOOLS[t]["act"] == act:
			return t
	return ""

## How far lifted the tool is, 0 on the target to 1 at the top of the swing, for `phase` 0..1.
static func lift(phase: float) -> float:
	if phase < WIND:
		return smoothstep(0.0, 1.0, phase / WIND)
	if phase < IMPACT:
		var k := (phase - WIND) / (IMPACT - WIND)
		return 1.0 - k * k
	return RECOIL * sin(PI * (phase - IMPACT) / (1.0 - IMPACT))

# ------------------------------------------------------------------ the pose (HunterAnim asks)
static func _u(act: String, phase: float) -> float:
	return lift(phase) * float(TOOLS[tool_of_act(act)]["lift"])

## Leg angles: Vector4(hip_l, knee_l, hip_r, knee_r), a planted stance that sinks into the strike.
static func legs(act: String, phase: float) -> Vector4:
	var sink := 1.0 - _u(act, phase)
	return Vector4(0.32 + sink * 0.08, -0.45 - sink * 0.2, -0.18, -0.3 - sink * 0.15)

## Forward lean of the body: back at the top of the swing, into it on the strike.
static func pitch(act: String, phase: float) -> float:
	var u := _u(act, phase)
	return 0.3 * (1.0 - u) - 0.1 * u

## Where the tool's butt, its direction and the right hand go, in the torso's space.
static func grip(tool: String, phase: float, sh_l: Vector3, sh_r: Vector3) -> Dictionary:
	var u := _u(act_of(tool), phase)
	var centre := (sh_l + sh_r) * 0.5
	if bool(TOOLS[tool]["two_hands"]):
		var low := centre + Vector3(0.0, -0.18, -0.18).lerp(Vector3(0.12, 0.14, -0.12), u)
		var dir := DIR_HIT.normalized().slerp(DIR_LIFT.normalized(), u)
		return {"left": low, "right": low + dir * GRIP_GAP, "dir": dir, "butt": low - dir * 0.1}
	var hand := sh_r + Vector3(-0.06, -0.2, -0.38).lerp(Vector3(-0.04, 0.28, -0.1), u)
	var dir_h := HAMMER_DIR_HIT.normalized().slerp(HAMMER_DIR_LIFT.normalized(), u)
	return {"left": sh_l + Vector3(0.14, -0.2, -0.36), "right": hand, "dir": dir_h, "butt": hand - dir_h * 0.05}

## HunterAnim._act_hands: [left hand, right hand, how much the right hand lets go of the weapon].
static func hands(act: String, phase: float, sh_l: Vector3, sh_r: Vector3) -> Array:
	var g := grip(tool_of_act(act), phase, sh_l, sh_r)
	return [g["left"], g["right"], 1.0]

# ------------------------------------------------------------------ the weapon and the tool in the rig
## Every frame, before the arms: which pose, how far the weapon is put away and the tool brought out.
static func tick(a: HunterAnim, dt: float, s: Dictionary) -> void:
	var tool := String(s.get("tool", ""))
	if TOOLS.has(tool) and tool != a.tool_kind:
		a.tool_kind = tool
		_build(a)
	a.tool_k = _ease(a.tool_k, TOOLS.has(tool), dt)
	var away := TOOLS.has(tool) or bool(s.get("holster", false))
	a.stow_k = _ease(a.stow_k, away, dt)
	if TOOLS.has(a.tool_kind):
		a.tool_ph = fposmod(float(s.get("tool_t", 0.0)), period(a.tool_kind)) / period(a.tool_kind)
	var held_back := a.stow_k < 0.5
	var shield := a.hand_l.get_node_or_null("Shield") if a.hand_l else null
	if shield:
		shield.visible = held_back
	if a.focus:
		a.focus.visible = held_back

## After the arms are posed: the tool in the hands.
static func place(a: HunterAnim) -> void:
	var node := a.torso.get_node_or_null("Tool") as Node3D
	if node == null:
		return
	node.visible = a.tool_k > 0.05 and TOOLS.has(a.tool_kind)
	if not node.visible or a.arm_l == null or a.arm_r == null:
		return
	var left := a.arm_l.transform * (a.el_l.transform * a.hand_l.position)
	var right := a.arm_r.transform * (a.el_r.transform * a.hand_r.position)
	var grip_dir := (right - left) if bool(TOOLS[a.tool_kind]["two_hands"]) else _hammer_dir(a)
	var dir := grip_dir.normalized() if grip_dir.length() > 0.02 else Vector3.UP
	var edge := Basis(Vector3.RIGHT, -PI * 0.5) * dir        # the blade, pick or face points where the swing goes
	var z_axis := -edge
	var x_axis := dir.cross(z_axis).normalized()
	z_axis = x_axis.cross(dir)
	var origin := left - dir * 0.1 if bool(TOOLS[a.tool_kind]["two_hands"]) else right - dir * 0.05
	node.transform = Transform3D(Basis(x_axis, dir, z_axis) * Basis.from_scale(Vector3.ONE * a.tool_k * SIZE), origin)

static func _ease(cur: float, on: bool, dt: float) -> float:
	return lerpf(cur, 1.0 if on else 0.0, 1.0 - exp(-POP_RATE * dt))

static func _hammer_dir(a: HunterAnim) -> Vector3:
	var u := _u("build", a.tool_ph)
	return HAMMER_DIR_HIT.normalized().slerp(HAMMER_DIR_LIFT.normalized(), u)

static func _build(a: HunterAnim) -> void:
	var old := a.torso.get_node_or_null("Tool")
	if old:
		old.free()
	var node := Node3D.new()
	node.name = "Tool"
	var wood := Models.toon(Color("8a5a32"))
	var iron := Models.toon(Color("9aa3b0"))
	var haft := float(TOOLS[a.tool_kind]["haft"])
	Models.part(node, Models.cyl(0.018, 0.022, haft, 8), wood, Vector3(0, haft * 0.5, 0))
	match a.tool_kind:
		"axe":
			Models.part(node, Models.box(0.05, 0.14, 0.05), iron, Vector3(0, haft - 0.05, 0))
			Models.part(node, Models.box(0.025, 0.16, 0.12), iron, Vector3(0, haft - 0.05, -0.08))
		"pickaxe":
			Models.part(node, Models.box(0.04, 0.04, 0.34), iron, Vector3(0, haft - 0.02, 0.0))
			var spike := Models.cyl(0.0, 0.02, 0.1, 6)
			Models.part(node, spike, iron, Vector3(0, haft - 0.02, -0.2), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))
			Models.part(node, spike, iron, Vector3(0, haft - 0.02, 0.2), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		"hammer":
			Models.part(node, Models.box(0.1, 0.1, 0.24), iron, Vector3(0, haft - 0.02, -0.04))
	node.visible = false
	a.torso.add_child(node)
