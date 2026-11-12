class_name ReceiverCue
extends Node
## What the body that receives a heal or a shield shows, one cue for every source (Meeko's heals, Albert's
## zone and aegis mend, knock heals, belt items, Boki carry passives, a Fuse release): a short soft rise of
## light up the body for a heal, a thin shell flash for a shield, both tinted by the giver's ability colour,
## and a "+N" in the heal or shield colour through the damage-number path (Fx.number).
## No particles, bursts or rings (a ground ring means gameplay): the cue is a pooled body-sized shell
## (shaders/receiver_cue.gdshader, mixed not added so it reads on bright ground), so it costs the same at
## every quality and reads at Very Low.
## Sources call heal() / shield(); Hunter.heal and Effects._heal already do. Checked by --receiver-cue-check.

const HEAL_COLOR := Color("8ff0a0")
const SHIELD_COLOR := HudStyle.SHIELD
const SHADER: Shader = preload("res://shaders/receiver_cue.gdshader")
const SHIELD_PREFIX := "+ "      # (a shield number must not merge into a heal number: Fx.number matches the prefix)
const POOL := 8                  # cues alive at once, shared by heals and shields
const RISE_S := 0.55             # s a heal's band takes to climb the body
const FLASH_S := 0.22            # s a shield's flash lasts
const GAP_S := 0.4               # s between two cues of one kind on one body (a zone ticking is one rise)
const NUMBER_MIN := 1.0          # smallest gain that shows a number
const TINT_WHITE := 0.15         # how far a heal's colour is lightened toward white
const SHIELD_WHITE := 0.5        # the same for a shield (paler, a thin bright shell)
const BODY_H := 1.8              # m: the shell's height (a Hunter; others scale by radius)
const BODY_R := 0.4              # m: the radius the shell is sized for

var m: Match
var shown := 0                   # (checks) cues started
var live := 0                    # cues on screen now
var last: Dictionary = {}        # (checks) the newest cue: kind, tint, number colour
var _slots: Array = []           # {mi, mat, e, t, dur, rise, a}
var _next := 0
var _gap := {}                   # [body, kind] -> s left before another cue of that kind

static func of(match_node: Match) -> ReceiverCue:
	var c := match_node.fx.get_node_or_null("ReceiverCue") as ReceiverCue
	if c == null:
		c = ReceiverCue.new(match_node)
		match_node.fx.add_child(c)
	return c

func _init(match_node: Match) -> void:
	m = match_node
	name = "ReceiverCue"

func _ready() -> void:
	for i in POOL:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("body_h", BODY_H)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.capsule(BODY_R, BODY_H)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_slots.append({"mi": mi, "mat": mat, "e": null, "t": 0.0, "dur": 1.0, "rise": false, "a": 1.0})

## `e` just gained `n` health from a giver of ability colour `tint` (transparent: the receiver's own).
static func heal(e: Ent, n: float, tint := Color.TRANSPARENT) -> void:
	if e == null or n <= 0.0 or not e.is_inside_tree():
		return
	var c := of(e.m as Match)
	if n >= NUMBER_MIN:
		e.m.fx.number(e.pos + Vector3(0, 1.6, 0), n, HEAL_COLOR, false, "+")
	c._start(e, "heal", tint, RISE_S, true, 1.0)

## Raise `e`'s shield to at least `amount` (a Hunter or a Boki); a real gain flashes the shell.
static func shield(e: Ent, amount: float, tint := Color.TRANSPARENT) -> void:
	var before := 0.0
	if e is Hunter:
		before = (e as Hunter).shield
		(e as Hunter).shield = maxf(before, amount)
	elif e is Kin:
		before = (e as Kin).shield
		(e as Kin).shield = maxf(before, amount)
	else:
		return
	var gained := amount - before
	if gained <= 0.0 or not e.is_inside_tree():
		return
	var c := of(e.m as Match)
	if gained >= NUMBER_MIN:
		e.m.fx.number(e.pos + Vector3(0, 1.9, 0), gained, SHIELD_COLOR, false, SHIELD_PREFIX)
	c._start(e, "shield", tint, FLASH_S, false, 1.0)

func _start(e: Ent, kind: String, tint: Color, dur: float, rise: bool, strength: float) -> void:
	var key := [e, kind]
	if float(_gap.get(key, 0.0)) > 0.0:
		return
	_gap[key] = GAP_S
	var col := _tint_of(e, kind, tint)
	var s: Dictionary = _slots[_next]
	_next = (_next + 1) % POOL
	s["e"] = e
	s["t"] = 0.0
	s["dur"] = dur
	s["rise"] = rise
	s["a"] = strength
	(s["mat"] as ShaderMaterial).set_shader_parameter("color", Color(col, 1.0))
	if not (s["mi"] as MeshInstance3D).visible:
		live += 1
	(s["mi"] as MeshInstance3D).visible = true
	shown += 1
	last = {"kind": kind, "tint": col, "number": HEAL_COLOR if kind == "heal" else SHIELD_COLOR}

## The cue's colour: the giver's ability colour lightened toward white; no giver colour, the receiver's own
## accent, else the plain heal or shield colour.
func _tint_of(e: Ent, kind: String, tint: Color) -> Color:
	var base := HEAL_COLOR if kind == "heal" else SHIELD_COLOR
	if tint.a > 0.0:
		base = tint
	elif e is Hunter and not (e as Hunter).cdat.is_empty():
		base = (e as Hunter).accent()
	return base.lerp(Color.WHITE, TINT_WHITE if kind == "heal" else SHIELD_WHITE)

func _process(dt: float) -> void:
	tick(dt)

## Ages the gaps and the cues on screen (called by _process; the check steps it by hand).
func tick(dt: float) -> void:
	if live == 0 and _gap.is_empty():
		return
	for key in _gap.keys():
		_gap[key] = float(_gap[key]) - dt
		if float(_gap[key]) <= 0.0:
			_gap.erase(key)
	for s in _slots:
		var mi: MeshInstance3D = s["mi"]
		if not mi.visible:
			continue
		s["t"] = float(s["t"]) + dt
		var e: Ent = s["e"]
		var k := float(s["t"]) / float(s["dur"])
		if k >= 1.0 or not is_instance_valid(e):
			mi.visible = false
			live -= 1
			continue
		var fade := (1.0 - k) * minf(1.0, k * 8.0)         # a quick fade in, a long soft fade out
		var wide := e.r / BODY_R * (1.12 + 0.12 * k)
		mi.global_position = e.pos + Vector3(0, BODY_H * 0.5 * e.r / BODY_R, 0)
		mi.scale = Vector3.ONE * wide
		var mat: ShaderMaterial = s["mat"]
		mat.set_shader_parameter("strength", float(s["a"]) * fade)
		mat.set_shader_parameter("band", 0.1 + 0.9 * (1.0 - pow(1.0 - k, 2.0)) if s["rise"] else -1.0)
