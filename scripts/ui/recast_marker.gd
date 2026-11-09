class_name RecastMarker
extends Label3D
## The world marker of an open recast (DECISIONS 2026-11-08): on the thing the second press will trigger
## (Motley's seed, Meeko's light, Albert's hammer, Sable's dagger) a thin ring on the ground in the Hunter's
## colour, and over it the key to press. The caster sees it, nobody else. It fades over the last FADE s of
## the window. The ring is an AimKit entry (pooled geometry, no draw call of its own); the key is one
## unoutlined Label3D, so a marker costs one draw call. Like AimKit it lives only while the kit refreshes it.

const RING_R := 0.9      # m: the ring's radius
const CAP_UP := 2.0      # m: the key's height over the ground point
const FADE := 0.5        # s: the fade-out at the end of the window
const KEEP := 0.1        # s of match time the key stays after the last refresh

var _stamp := -9.0
var _m: Match

## Refresh the marker for the kit's open recast (nothing when none is open).
static func sync(k: ArchKit) -> void:
	var at := k.recast_at()
	if not at.is_finite():
		return
	var m: Match = k.m
	var mark := m.get_node_or_null("RecastMarker") as RecastMarker
	if mark == null:
		mark = RecastMarker.new()
		mark._m = m
		m.add_child(mark)
	var left := k.recast_left()
	var a := 1.0 if left < 0.0 else clampf(left / FADE, 0.0, 1.0)
	var col := AimKit.hero_col(k.h)
	AimKit.ring(k.h, "recast", {"at": at, "r": RING_R, "col": col, "alpha": a, "lw": 0.1})
	mark._stamp = m.time
	mark.text = Settings.key_cap(k.recast_key())
	mark.modulate = Color(col.lerp(Color.WHITE, 0.35), a)
	mark.visible = true
	mark.global_position = at + Vector3(0, CAP_UP, 0)

func _init() -> void:
	name = "RecastMarker"
	font_size = 72
	pixel_size = 0.008
	outline_size = 0
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	visible = false

func _process(_dt: float) -> void:
	if visible and _m.time - _stamp > KEEP:
		visible = false
