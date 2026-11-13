class_name HunterFall
extends RefCounted
## The knocked-down beat (docs/decisions/0019-downed-wisp.md): for 0.4-0.5 s after a Hunter goes down, before the
## Wisp takes over, the hero staggers along the hit, drops to a knee and collapses. A Hero plays its own death clip
## run over the beat on its weight's curve (WardenClips), a Hero without one kneels and slumps (HunterAnim). The
## body stays where it went down, facing the way it faced, pushed along the hit, and fades out as it lands while
## the Wisp rises out of it. HunterWisp runs it from `downed` alone, so a copy of another game's hunter falls the
## same way. Visual only: gameplay never reads it, the Wisp is live and revivable from the first frame.

## Per weight (Hunter.cls). time: s, the whole beat. push: m the stagger carries the body along the hit.
## curve: the death clip runs as k^curve over the beat (above 1 a heavy body holds, then drops hard; below 1 a
## light one folds at once). thud: dust puffs where the body hits the ground (0: none).
const STYLE := {
	"light": {"time": 0.4, "push": 0.35, "curve": 0.8, "thud": 0},
	"medium": {"time": 0.45, "push": 0.3, "curve": 1.0, "thud": 0},
	"heavy": {"time": 0.5, "push": 0.2, "curve": 1.5, "thud": 12},
}
const STAGGER := 0.35        # share of the beat the push takes, eased out: shoved, then caught
const LAND := 0.7            # share of the death clip where the heroes are on the ground (most clips)
const FADE_FROM := 0.6       # share of the death clip the body starts fading from; gone at the end of the beat
const KNOCKER := "fall_knocker"   # hunter meta: who downed it, kept until its beat starts
const META := "fall"

var time := 0.45             # s
var push := 0.3              # m
var curve := 1.0
var thud := 0
var k := 0.0                 # 0..1 through the beat
var gone := 0.0              # 0..1 how far the body has faded out
var landed := false          # the body is on the ground
var from := Vector3.ZERO     # where the body went down
var facing := 0.0            # rad: the way it faced then
var dir := Vector2.ZERO      # the hit's way along the ground (unit): the stagger goes with it
var meshes: Array = []       # every mesh of the hero, faded together

## Who downed a hunter (Match.knock, or the knock event of another game's hunter): its stagger goes away from
## them. Before the beat starts it waits on the hunter; a beat already running turns to it.
static func knocked(h: Hunter, by: Ent) -> void:
	var fall := of(h)
	if fall:
		fall.dir = _away(h, by)
	elif not h.downed:
		h.set_meta(KNOCKER, by)

## The beat a hunter is in, or null.
static func of(h: Hunter) -> HunterFall:
	return h.get_meta(META) as HunterFall if h.has_meta(META) else null

## Starts the beat of a hunter that just went down (HunterWisp's pop-in).
static func start(h: Hunter) -> HunterFall:
	var fall := HunterFall.new()
	var style: Dictionary = STYLE.get(h.cls, STYLE["medium"])
	fall.time = float(style["time"])
	fall.push = float(style["push"])
	fall.curve = float(style["curve"])
	fall.thud = int(style["thud"])
	fall.from = h.position
	fall.facing = h.face
	fall.dir = _away(h, (h.get_meta(KNOCKER) if h.has_meta(KNOCKER) else null))
	h.remove_meta(KNOCKER)
	fall.meshes = h.model.find_children("*", "GeometryInstance3D", true, false)
	h.set_meta(META, fall)
	return fall

## Ends the beat (landed, revived or out): the body back on the hunter and opaque.
static func stop(h: Hunter) -> void:
	var fall := of(h)
	if fall == null:
		return
	h.remove_meta(META)
	if h.model:
		h.model.position.x = 0.0
		h.model.position.z = 0.0
	fall._fade(0.0)

## How far into its death clip the hero is (HunterAnim state "fall"), -1 when no beat runs.
static func clip_k(h: Hunter) -> float:
	var fall := of(h)
	return pow(fall.k, fall.curve) if fall else -1.0

## The way the body is drawn facing: while the beat runs, the way it faced when it went down.
static func face_of(h: Hunter) -> float:
	var fall := of(h)
	return fall.facing if fall else h.face

## Poses the body at k_now (0..1 through the beat): where it went down, pushed along the hit, fading as it lands.
func pose(h: Hunter, k_now: float) -> void:
	k = k_now
	var shove := dir * push * (1.0 - pow(1.0 - minf(1.0, k / STAGGER), 3.0))
	var body := from + Vector3(shove.x, 0.0, shove.y)
	h.model.position.x = body.x - h.position.x
	h.model.position.z = body.z - h.position.z
	var clip := pow(k, curve)
	_fade(smoothstep(FADE_FROM, 1.0, clip))
	if not landed and clip >= LAND:
		landed = true
		if thud > 0 and h.visible:
			h.m.fx.dust(body, thud)

func _fade(to: float) -> void:
	if to == gone:
		return
	gone = to
	for mesh in meshes:
		if is_instance_valid(mesh):
			(mesh as GeometryInstance3D).transparency = to

## The way along the ground from `by` to the hunter; straight back from its facing when nobody (a fall, the storm),
## as a hit from the front would push it.
static func _away(h: Hunter, by: Variant) -> Vector2:
	var src := by as Ent if is_instance_valid(by) else null
	if src:
		var off := Vector2(h.pos.x - src.pos.x, h.pos.z - src.pos.z)
		if off.length() > 0.05:
			return off.normalized()
	return Vector2(sin(h.face), cos(h.face))
