class_name WispProc
extends Node3D
## The look of a carried passive triggering (DECISIONS 2026-11-09: the carry passive is always on and the wisp
## shows as its source; no bursts). When a passive the wisp carries acts on its hunter (a heal, a shield soak
## or a damage cut, a damage bonus on a shot, a run speed boost), the wisp gives one small flash in its Boki's
## own glow (the shiny colours when shiny) and a thin streak to where it acted. At most one cue per RATE_S per
## wisp. One WispProc node per wisp holds its two meshes for the whole match: nothing is built per cue.
## It reads the hunter's state (hp, shield, armor, muzzle, speed), so a rival's wisp cues too, from the snapshot.
## With the wisps off, a walking Boki carried by order (the Return order) cues the same way while it rides.
## Your own Boki's first cue also gives the one-time tip that names the passive (tip, Match._tips).

const RATE_S := 0.5        # s between cues of one wisp
const FLASH_S := 0.25      # s the flash takes to swell and fade
const STREAK_S := 0.2      # s the streak takes to fade
const FLASH_R := 0.14      # m: the flash's radius at its biggest
const STREAK_R := 0.012    # m: the streak's radius (thin, like the thief tether)
const CHEST_Y := 1.2       # m above a hunter's feet where a heal, shield or boost lands
const SHOT_REACH := 6.0    # m the damage streak runs along the aim
const RUN_START := 3.0     # m/s the hunter must pass, from standing, for the speed boost to read
const TIP_KEEP_S := 6.0    # s a cue may wait for the first-proc tip (the tip lane can be busy)
const KINDS := {           # cue kind -> the carry passive stats that make it
	"heal": ["regen"],
	"shield": ["armor", "damage_reduction", "knockback_resist"],
	"damage": ["damage"],
	"speed": ["move_speed"],
}

static var _flash_mesh: SphereMesh
static var _streak_mesh: CylinderMesh

var cues := 0                    # how many cues this wisp has played (the checks count them)
var last_kind := ""
var _flash: MeshInstance3D
var _streak: MeshInstance3D
var _glow := Color.WHITE
var _next := 0.0                 # match time the next cue may play
var _t0 := -1e9                  # match time of the last cue
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _seen := false
var _hp := 0.0
var _soak := 0.0                 # armor plus kin shield last frame
var _muzzle := 0.0
var _moving := false

## Watch one wisp's hunter this frame and play a cue if a passive of the wisp acted (KinWisp.render calls it).
static func watch(k: Kin) -> void:
	var p := k.get_node_or_null("Proc") as WispProc
	if p == null:
		p = _make(k)
	p._look(k)

## A walking Boki (no wisp): watched while its hunter carries it by order; off them its watch rests, so
## the hp or shield it missed meanwhile is not read as a proc when it is carried again (KinWisp.render calls it).
static func watch_carried(k: Kin) -> void:
	if k.owner_h != null and k.owner_h.kin_carry_on():
		watch(k)
		return
	var p := k.get_node_or_null("Proc") as WispProc
	if p != null:
		p._seen = false
		p._fade(k.m.time)

## The first-proc tip for your Boki `k`, "<Boki>'s <passive>: <what it does>" from its carry data, while its
## last cue is under TIP_KEEP_S old and this save has not had the tip ("" otherwise). Match._tips shows it once
## (Save.d.tutorial.proc); the wisp flashes again so the eye finds it.
static func tip(k: Kin) -> String:
	if Save.d["tutorial"].get("proc", false):
		return ""
	var p := k.get_node_or_null("Proc") as WispProc
	if p == null or p.last_kind == "" or k.m.time - p._t0 > TIP_KEEP_S:
		return ""
	var kinds: Array = KINDS[p.last_kind]
	var acted := k.ks.carry_passives.filter(func(ps): return String(ps["stat"]) in kinds)
	var passive := k.ks.carry_name if k.ks.carry_name != "" else "carry passive"
	p._play(k, p.last_kind, p._to, k.m.time)
	return "%s's %s: %s" % [k.rec.get("name", "Your Boki"), passive, KinText.passives(acted)]

static func _make(k: Kin) -> WispProc:
	if _flash_mesh == null:
		_flash_mesh = SphereMesh.new()
		_flash_mesh.radius = 1.0
		_flash_mesh.height = 2.0
		_flash_mesh.radial_segments = 8
		_flash_mesh.rings = 4
		_streak_mesh = CylinderMesh.new()
		_streak_mesh.top_radius = 1.0
		_streak_mesh.bottom_radius = 1.0
		_streak_mesh.height = 1.0
		_streak_mesh.radial_segments = 4
		_streak_mesh.rings = 1
	var p := WispProc.new()
	p.name = "Proc"
	p._glow = Shiny.col(k.species, k.rec, "glow")
	p._flash = p._part(_flash_mesh)
	p._streak = p._part(_streak_mesh)
	k.add_child(p)
	return p

func _part(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(_glow, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi

static func carries(k: Kin, kind: String) -> bool:
	if k.ks == null:
		return false
	for ps in k.ks.carry_passives:
		if String(ps["stat"]) in KINDS[kind]:
			return true
	return false

func _look(k: Kin) -> void:
	var h := k.owner_h
	var now: float = k.m.time
	if h == null or h.downed or h.out:
		_seen = false
		_fade(now)
		return
	var soak := h.armor + h.kin_shield
	var speed := Vector2(h.vel.x, h.vel.z).length()
	var kind := ""
	var to := h.position + Vector3(0, CHEST_Y, 0)
	if _seen:
		if carries(k, "heal") and h.hp > _hp:
			kind = "heal"
		elif carries(k, "shield") and (soak < _soak - 0.01 or h.hp < _hp - 0.01):
			kind = "shield"
		elif carries(k, "damage") and h.muzzle_t > _muzzle:
			kind = "damage"
			var aim := h.aim_dir()
			to += Vector3(aim.x, 0.0, aim.y) * SHOT_REACH
		elif carries(k, "speed") and speed > RUN_START and not _moving:
			kind = "speed"
			to = h.position
	_hp = h.hp
	_soak = soak
	_muzzle = h.muzzle_t
	_moving = speed > RUN_START * 0.5
	_seen = true
	if kind != "" and now >= _next:
		_play(k, kind, to, now)
	_fade(now)

## Play a cue now: the flash at the wisp, the streak from it to `to`.
func _play(k: Kin, kind: String, to: Vector3, now: float) -> void:
	_next = now + RATE_S
	_t0 = now
	_from = k.global_position
	_to = to
	cues += 1
	last_kind = kind

func _fade(now: float) -> void:
	var f := (now - _t0) / FLASH_S
	var s := (now - _t0) / STREAK_S
	_flash.visible = f < 1.0
	_streak.visible = s < 1.0
	if _flash.visible:
		var r := FLASH_R * (0.4 + 0.6 * sin(f * PI * 0.5))
		_flash.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), _from)
		(_flash.material_override as StandardMaterial3D).albedo_color = Color(_glow, 0.9 * (1.0 - f))
	if _streak.visible:
		var d := _to - _from
		var ln := d.length()
		var axis := d / maxf(ln, 0.001)
		var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
		var frame := Basis(side * STREAK_R, axis * ln, side.cross(axis) * STREAK_R)
		_streak.global_transform = Transform3D(frame, (_from + _to) * 0.5)
		(_streak.material_override as StandardMaterial3D).albedo_color = Color(_glow, 0.8 * (1.0 - s))
