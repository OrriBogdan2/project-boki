extends RefCounted
## --land-weight-check: PRIORITIES area 4 (blends and gaps). The landing squash of every weight class
## (content/rules/land_feel.json): a real HunterAnim per class takes a jump, a terrace drop and a dive's plunge
## down, and the squash it plays (land_k) must bottom out at the class's depth and be gone in the class's seconds
## (one frame either way). The source's two reads stay pinned: the light thief's jump is up again in 0.15 s, the
## heavy slam is the deepest squash and ~0.5 s long; and heavier never lands quicker or shallower than lighter.
## The .glb land clip (WardenClips.land_play): on a footage cell ("clip") every Hero of the class holds it for the
## cell's seconds and plays the same keys of it; elsewhere it keeps the Hero's own warden_anim land data.
## No burst, ring or disc on landing (DECISIONS): the squash is the whole of it. Never touches the save.

const DT := 1.0 / 60.0
const FALLS := {"hop": 6.8, "drop": 9.4, "dive": 25.0}  # m/s down at touchdown: a jump, a 3 m drop, a dive
const FRAMES_TOL := 1.5  # frames the squash may be off its seconds
const CLASSES := ["light", "medium", "heavy"]

var bad := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	print("LAND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var lengths := {}
	var depths := {}
	for cls: String in CLASSES:
		for way: String in FALLS:
			var tier: int = ["hop", "hop", "drop", "dive"].find(way) if way != "hop" else 1
			var want := HunterAnim.land_feel(cls, tier)
			var depth := clampf(float(FALLS[way]) / 14.0, want.x, 1.0) if tier > 1 else want.x
			var got := _land(cls, float(FALLS[way]))
			ok(absf(got.x - depth) < 0.01, "%s %s: squash bottoms out at %.2f (data %.2f)" % [cls, way, got.x, depth])
			ok(absf(got.y - want.y) <= DT * FRAMES_TOL, "%s %s: gone in %.3f s (data %.3f)" % [cls, way, got.y, want.y])
			lengths[cls + way] = got.y
			depths[cls + way] = got.x
	var light_hop := HunterAnim.land_feel("light", 1)
	ok(absf(light_hop.y - 0.15) < 0.001, "light jump: up again in 0.15 s (source: crouch + rise)")
	ok(
		HunterAnim.land_feel("heavy", 2).x == 1.0 and absf(HunterAnim.land_feel("heavy", 2).y - 0.5) < 0.001,
		"heavy drop: the deepest squash, 0.5 s (source: the slam's recovery)"
	)
	ok(HunterAnim.land_feel("heavy", 3) == HunterAnim.land_feel("heavy", 2), "heavy dive lands like its drop")
	for way: String in ["drop", "dive"]:
		ok(
			depths["heavy" + way] >= depths["medium" + way] and depths["medium" + way] >= depths["light" + way],
			"%s: heavier never squashes shallower than lighter" % way
		)
		ok(
			(
				lengths["heavy" + way] >= lengths["medium" + way]
				and lengths["medium" + way] >= lengths["light" + way] - DT
			),
			"%s: heavier never settles quicker than lighter" % way
		)
	_clips()
	print("LAND_WEIGHT_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Vector2(deepest land_k, seconds until it is gone) for one class touching down at fall_v m/s.
func _land(cls: String, fall_v: float) -> Vector2:
	var id := ""
	for a in Arch.ids():
		if Arch.weight(String(a)) == cls:
			id = String(a)
			break
	var m := Models.hunter(cls, Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var an := HunterAnim.new(m, 1)
	var air := {"grounded": false, "vel": Vector3(0, -fall_v, 0), "face": 0.0, "fired": 99.0}
	var ground := {"grounded": true, "vel": Vector3.ZERO, "face": 0.0, "fired": 99.0}
	for i in 5:
		an.update(DT, ground)
	for i in 4:
		an.update(DT, air)
	var deepest := 0.0
	var frames := 0
	an.update(DT, ground)  # (the touchdown frame: the squash starts and takes its first step)
	while an.land_k > 0.0 and frames < 120:
		deepest = maxf(deepest, an.land_k)
		an.update(DT, ground)
		frames += 1
	m.free()
	return Vector2(deepest + an.land_rate * DT, (frames + 1) * DT)


## Every Hero with a land clip: the footage cells retime it to the class's seconds over the same keys.
func _clips() -> void:
	for a: String in WardenGlb.ART:
		var land: Dictionary = WardenClips.data(String(WardenGlb.ART[a])).get("land", {})
		if land.is_empty():
			continue
		var cls := Arch.weight(a)
		for tier in [1, 2, 3]:
			var way: String = ["hop", "hop", "drop", "dive"][tier]
			var base: Dictionary = land["hop" if tier == 1 else "drop"]
			var got := WardenClips.land_play(base, cls, tier)
			var cell: Dictionary = Content.rules("land_feel")[cls][way]
			if not bool(cell.get("clip", false)):
				var own := "%s %s %s: own land clip hold %.2f s" % [a, cls, way, got["dur"]]
				ok(float(got["dur"]) == float(base["dur"]), own)
				continue
			var keys := float(base["dur"]) * float(base.get("rate", 1.0))
			var same := absf(float(got["dur"]) * float(got["rate"]) - keys) < 0.001
			var what := (
				"%s %s %s: land clip held %.2f s (data %.2f), same %.2f s of keys"
				% [a, cls, way, got["dur"], cell["s"], keys]
			)
			ok(absf(float(got["dur"]) - float(cell["s"])) < 0.001 and same, what)
