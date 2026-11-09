class_name ExitSignal
extends RefCounted
## How an exit reads from across the map (docks, hatches, uplinks all the same): where it is, whether it
## is live, and whether someone is on it. Three states, shown by a sky beam and the ground zone:
##   IDLE   a short dim stub and a faint zone in the exit's own colour (docks amber, hatches violet, uplinks cyan)
##   ACTIVE a tall beam in the colour of the team that started it, pulsing faster as the countdown runs out
##   USED   the same beam, thicker and steady, with the zone filled in the colour of whoever stands on it
## A closed dock shows nothing. No particles: two meshes per exit, made once (attach) and only recoloured.

enum { OFF, IDLE, ACTIVE, USED }

const KIND_COLOR := {"dock": ExitModels.DOCK, "hatch": ExitModels.HATCH, "outpost": ExitModels.UPLINK}
const CONTESTED := Color("ff7a5a")   # a rival in an uplink's yard
const SKY_H := 70.0                  # m, the beam's full height: seen over the walls and the trees
const STUB_H := 9.0                  # m, an idle exit's marker
const BEAM_R := 0.45                 # m, an active beam's radius (a used one is twice as thick)
const BEAM_A := [0.0, 0.14, 0.3, 0.5]            # beam alpha by state
const ZONE_A := [0.0, 0.22, 0.55, 0.85]         # zone ring alpha by state
const PULSE_SLOW := 2.0              # rad/s of the pulse with the countdown full
const PULSE_FAST := 11.0             # ... and nearly out
const ZONE_Y := 0.13                 # m above the ground: clear of the pier deck

## The state an exit is in. `who` is the team standing on it (-1 for nobody).
static func phase(x: Dictionary, who: int) -> int:
	var live := false
	match String(x["kind"]):
		"dock":
			if x["state"] == "closed":
				return OFF
			live = x["state"] in ["called", "boarding"]
		"hatch":
			live = x["state"] in ["unlocking", "open"]
		"outpost":
			live = x["state"] in ["charging", "open"]
	if not live:
		return IDLE
	return USED if who >= 0 else ACTIVE

## 0..1 of the countdown left, 1 when it has no end (an open hatch, a tutorial lift).
static func left(x: Dictionary) -> float:
	var t := float(x.get("t", 0.0))
	match String(x["state"]):
		"called": return clampf(t / Exits.CALL_T, 0.0, 1.0)
		"boarding": return clampf(t / Exits.BOARD_T, 0.0, 1.0)
		"unlocking": return clampf(t / Exits.HATCH_UNLOCK_T, 0.0, 1.0)
		"charging": return 1.0 - clampf(float(x["prog"]), 0.0, 1.0)
		"open" when x["kind"] == "outpost" and t < 1e8: return clampf(t / Exits.LIFT_T, 0.0, 1.0)
	return 1.0

static func team_color(team: int) -> Color:
	return Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()]

## The beam's and zone's colours and alphas for `ph`, as [beam colour, zone colour].
static func colors(x: Dictionary, ph: int, who: int, pulse: float) -> Array:
	var kind: Color = KIND_COLOR[x["kind"]]
	var holder := int(x["team"])
	var beam := team_color(holder) if ph >= ACTIVE and holder >= 0 else kind
	var zone := kind
	if ph == USED:
		beam = team_color(who)
		zone = beam
	elif ph == ACTIVE and x.get("contested", false):
		zone = CONTESTED
	var wave := 0.7 + 0.3 * pulse if ph == ACTIVE else 1.0
	return [Color(beam, float(BEAM_A[ph]) * wave), Color(zone, float(ZONE_A[ph]) * wave)]

## Adds the beam and the zone ring (named Signal and Zone) to an exit's model. `zone_d` is the ground
## zone's diameter in m: the radius the game itself uses for the exit.
static func attach(root: Node3D, kind: Color, zone_d: float) -> void:
	var zone := MeshInstance3D.new()
	zone.name = "Zone"
	zone.mesh = Models.flat_quad(zone_d)
	zone.material_override = Models.ring_mat(Color(kind, ZONE_A[IDLE]), 0.05)
	zone.position.y = ZONE_Y
	root.add_child(zone)
	var sig := Node3D.new()
	sig.name = "Signal"
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = Models.cyl(1.0, 1.0, SKY_H, 8)
	beam.material_override = Models.glow_mat(Color(kind, BEAM_A[IDLE]))
	beam.position.y = SKY_H * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sig.add_child(beam)
	root.add_child(sig)

## Puts the exit's model in state `ph` (called every tick; it only touches the scene when the look changed).
static func show(x: Dictionary, ph: int, who: int, time: float) -> void:
	var n: Node3D = x["node"]
	var sig := n.get_node("Signal") as Node3D
	var zone := n.get_node("Zone") as MeshInstance3D
	sig.visible = ph != OFF
	zone.visible = ph != OFF
	if ph == OFF:
		return
	var pulse := 0.0
	if ph == ACTIVE:
		pulse = 0.5 + 0.5 * sin(time * lerpf(PULSE_FAST, PULSE_SLOW, left(x)))
	var cols := colors(x, ph, who, pulse)
	var key := [ph, cols[0], cols[1]]
	if key == x.get("signal"):
		return
	x["signal"] = key
	var w := BEAM_R * (2.0 if ph == USED else 1.0)
	var h := STUB_H / SKY_H if ph == IDLE else 1.0
	sig.scale = Vector3(w, h, w)
	var beam_mat := (sig.get_node("Beam") as MeshInstance3D).material_override as ShaderMaterial
	beam_mat.set_shader_parameter("color", cols[0])
	(zone.material_override as ShaderMaterial).set_shader_parameter("color", cols[1])
