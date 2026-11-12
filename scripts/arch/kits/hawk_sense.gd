class_name HawkSense
extends RefCounted
## Lace's passive, Hawk Sense (the source's injured-hunter vision): rivals under the health line (resource
## sense_hp) within sense_r are seen by her side through fog, grass and rocks (Match.can_see asks seen_by) and
## revealed to all (reveal_t) for as long as they stay hurt and close. On her side's screens each one also
## wears a glowing outline in her colour that shows through rocks and walls: the x-ray shell your squad's
## Boki wear (kin_aura_xray), laid over the body as a material overlay. It goes off within HOLD_S of the
## rival healing past the line, leaving range or dying.

const XRAY: Shader = preload("res://shaders/kin_aura_xray.gdshader")
const SCAN_S := 0.3            # s between scans for hurt rivals
const HOLD_S := 0.4            # s a sensed rival stays revealed after the last scan that found them
const STRENGTH := 0.6          # the outline's brightness (as the Boki shells: brighter washes the body out)
const GROW := 0.02             # m the shell stands off the body

const TEAMS_META := "hawk_teams"   # on a sensed rival: a bit per team whose Lace senses them

var k: ArcherKit
var seen := {}                 # Hunter -> {t: s left, mats: the body it was put on, meshes: [MeshInstance3D]}
var _scan_t := 0.0
var _mat: ShaderMaterial

func _init(kit: ArcherKit) -> void:
	k = kit
	_mat = ShaderMaterial.new()
	_mat.shader = XRAY
	_mat.set_shader_parameter("color", Color(String(k.d.get("color", "#ffffff"))))
	_mat.set_shader_parameter("strength", STRENGTH)
	_mat.set_shader_parameter("grow", GROW)

func tick(dt: float) -> void:
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan()
	if seen.is_empty():
		return
	for f in seen.keys():
		var e: Dictionary = seen[f]
		e["t"] = float(e["t"]) - dt
		if float(e["t"]) <= 0.0 or not is_instance_valid(f):
			_forget(f)
		elif not is_same(e["mats"], (f as Hunter).mats):
			_outline_off(e)              # (the model was rebuilt: put it on the new one)
			_outline_on(f, e)

## Whether a Lace on `team` senses `f` (so her side sees them wherever they stand).
static func seen_by(f: Hunter, team: int) -> bool:
	return int(f.get_meta(TEAMS_META, 0)) & (1 << team) != 0

## Whether `f` is under Hawk Sense right now (revealed, and outlined for Lace's side).
func senses(f: Hunter) -> bool:
	return seen.has(f)

## Takes every outline off (the kit is swapped away or the match ends).
func clear() -> void:
	for f in seen.keys():
		_forget(f)

func _forget(f: Variant) -> void:
	_outline_off(seen[f])
	seen.erase(f)
	if is_instance_valid(f):
		var teams := int((f as Hunter).get_meta(TEAMS_META, 0)) & ~(1 << k.h.team)
		(f as Hunter).set_meta(TEAMS_META, teams)

func _scan() -> void:
	var rd := k.res_def()
	var line := float(rd.get("sense_hp", 0.5))
	var reach := float(rd.get("sense_r", 22.0))
	for f in k.m.foes_of(k.h.team):
		if not (f is Hunter) or f.dead or f.hp >= f.max_hp * line or k.h.flat_dist(f) >= reach:
			continue
		f.reveal_t = maxf(f.reveal_t, HOLD_S)
		if seen.has(f):
			seen[f]["t"] = HOLD_S
		else:
			seen[f] = {"t": HOLD_S}
			f.set_meta(TEAMS_META, int(f.get_meta(TEAMS_META, 0)) | (1 << k.h.team))
			_outline_on(f, seen[f])

## The outline only shows to Lace's own side (the reveal itself is the shared reveal_t).
func _outline_on(f: Hunter, e: Dictionary) -> void:
	e["mats"] = f.mats
	e["meshes"] = []
	var lp: Node = k.m.get("player")
	if f.model == null or lp == null or int(lp.get("team")) != k.h.team:
		return
	for mi: MeshInstance3D in f.model.find_children("*", "MeshInstance3D", true, false):
		var own := mi.material_override as ShaderMaterial      # (ground rings and glow shells get no outline)
		if mi.material_overlay == null and not (own and own.shader in [Models.GLOW, Models.RING, Models.AURA]):
			mi.material_overlay = _mat
			e["meshes"].append(mi)

func _outline_off(e: Dictionary) -> void:
	for mi in e.get("meshes", []):
		if is_instance_valid(mi) and (mi as MeshInstance3D).material_overlay == _mat:
			(mi as MeshInstance3D).material_overlay = null
