class_name LegendaryReveal
extends RefCounted
## When this match's legendary Boki turns up (Legendary), every player knows it, the way a world
## event reads from far: a tall soft beam in its type colour over it (no ground ring: DECISIONS),
## a star on the minimap with an arrow at the edge when it is off the map, one line in the message
## lane saying which way it is, and a sting everyone hears (audio/legendary_sting.wav, made by
## tools/gen_legendary_sfx.py). Beam and star go away when it is caught or leaves.
## Runs on every game: the roll is seeded (SpawnPlan.legend is the same everywhere), so a client
## finds the wild Boki of that species once it turns up; nothing new goes over the net.

const STING_DB := -2.0         # the sting's level: heard by everyone, no falloff
const PULSE_HZ := 0.5          # the beam's slow breathing (cycles per second)
const BEAM_W := 1.3            # the beam's width over the lair beam's (it stands in open ground)

var plan: SpawnPlan
var kin: Kin = null            # the legendary while it is out; null before and after
var beam: Node3D = null
var banner := ""               # the line shown when it turned up ("" once it is gone)
var done := false              # it came and went: nothing more this match

func _init(spawn_plan: SpawnPlan) -> void:
	plan = spawn_plan

## Every frame (SpawnPlan.tick): find it once it turns up, keep the beam over it, clear up after it.
func tick() -> void:
	if done or plan.legend == "":
		return
	var m := plan.m
	if kin == null:
		if m.time < float(Legendary.rules()["delay_s"]):
			return
		kin = _find(m)
		if kin != null:
			_show(m)
		return
	if not is_instance_valid(kin) or kin.dead:
		clear()
		return
	beam.position = kin.global_position
	var k := 1.0 + 0.08 * sin(m.time * TAU * PULSE_HZ)
	beam.scale = Vector3(BEAM_W * k, 1.0, BEAM_W * k)

## The wild Boki of the rolled species (the host already holds it in SpawnPlan.legend_kin).
func _find(m: Match) -> Kin:
	if is_instance_valid(plan.legend_kin):
		return plan.legend_kin
	for k in m.kins:
		if is_instance_valid(k) and not k.dead and k.species == plan.legend and k.owner_h == null and k.lost_from == "":
			return k
	return null

func color() -> Color:
	return DexView.type_col(DexView.type_of(plan.legend))

func _show(m: Match) -> void:
	beam = BossModels.alert_beam(color())
	m.add_child(beam)
	beam.position = kin.global_position
	m.sfx("legendary_sting", null, STING_DB)
	var species_name := String(Data.KIN[plan.legend]["name"])
	banner = "A legendary Boki has appeared: %s" % species_name
	if m.player:
		banner += ", " + m.direction_word(m.player.pos, kin.global_position)
	if m.hud:
		m.hud.toast(banner, color())

## It was caught or it left: the beam and the star go.
func clear() -> void:
	if is_instance_valid(beam):
		beam.queue_free()
	beam = null
	kin = null
	banner = ""
	done = true

## The star on the minimap, or an arrow at its edge (Hud minimap).
func minimap(hud, inner: Rect2, to_map: Callable, on_map: Callable) -> void:
	if kin == null or not is_instance_valid(kin) or hud.full_map == null:
		return
	var pv: Vector2 = to_map.call(kin.global_position)
	if on_map.call(pv, 5.0):
		hud.full_map.marker(hud.c, "star", pv, 5.0, color(), "active")
	else:
		hud._edge_arrow(inner, inner.get_center(), pv, color())
