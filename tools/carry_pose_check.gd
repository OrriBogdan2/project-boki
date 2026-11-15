extends RefCounted
## --carry-pose-check: the Heartspark carry layer (WardenCarry.hold_mote) on all 12 Hunters. In a real match the
## carrier shows the layer (the off hand holds the mote at the chest, the Heart's spark rides it), the legs keep
## playing the run (the layer touches only the off arm), LMB still fires, and the layer drops cleanly when the Heart
## is dropped, the carrier is knocked, extracts, or the Heartspark passes to someone else. Never touches the save.

const OWN_MODELS := {"archer": "hem", "thief": "sable", "tender": "pip", "gunslinger": "vex", "ashwick": "cinder",
	"mage": "ryzz", "dolm": "tarek", "rimewright": "claire", "dredge": "dredge", "bulwark": "breaker",
	"ostra": "ostra", "juggernaut": "kael"}
const SETTLE_S := 1.2      # s: the layer eases in (WardenCarry.FADE) and the run gets going
const STRIDE_MIN := 0.05   # m: a running shin swings at least this far front to back
const HAND_NEAR := 0.3     # of the Hunter's height: the held hand lies this near the mote
const FIRE_S := 0.8        # s: LMB held, and the same again after the release (a bow looses on the release)
const SPARK_LAG := 0.3     # m: the spark follows the hand a frame late, at a run

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("CARRY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m_main: Node) -> void:
	main = m_main
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for id in OWN_MODELS:
		await _hero(String(id))
	print("CARRY_POSE_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Steps the match and poses the player by hand (the match's own frames are off, so the time is exact).
func _step(m: Match, secs: float, watch: Callable = Callable()) -> void:
	var sync := m.player.model.get_node("Warden/Sync")
	sync.set_process(false)
	for i in int(secs / Match.DT):
		m.step(Match.DT)
		m.player.render(Match.DT, 1.0)
		sync.call("_process", Match.DT)
		if watch.is_valid():
			watch.call()
		await main.get_tree().process_frame

func _clips(h: Hunter) -> WardenClips:
	var sync := h.model.get_node_or_null("Warden/Sync")
	return sync.get("clips") if sync != null else null

func _hero(id: String) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 7311, "no_drop": true, "heart": true,
		"god": true, "arch": id, "cls": Arch.weight(id), "weapon": Arch.signature(id)})
	m.set_process(false)
	for o in m.hunters:
		if o != m.player:
			o.ctrl = "idle"
	var P := m.player
	var H: Heart = m.heart
	var clips := _clips(P)
	ok(clips != null, "%s: wears its clips in the match" % id)
	if H == null or clips == null:
		m.queue_free()
		return
	_take(H, P)
	P.inp["move"] = Vector2(0, -1)
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var shin := WardenSkeleton.find(sk, "shin.R")
	var hips := WardenSkeleton.find(sk, "hips")
	var z := [INF, -INF]
	await _step(m, SETTLE_S, func():
		var below := sk.get_bone_global_pose(shin).origin - sk.get_bone_global_pose(hips).origin
		var at := (sk.global_transform.basis * below).z
		z[0] = minf(z[0], at)
		z[1] = maxf(z[1], at))
	var mote: Vector3 = P.model.get_meta(WardenCarry.MOTE, Vector3.INF)
	ok(clips.heart_w >= 1.0 and mote != Vector3.INF, "%s: the carrier shows the layer and a held mote" % id)
	var side := String(WardenClips.data(OWN_MODELS[id]).get("heart_hand", "L"))
	var hand := sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hand." + side)).origin
	ok(hand.distance_to(mote) <= HAND_NEAR * 1.6 * absf(P.model.scale.y), "%s: the %s hand holds the mote (%.2f m)"
			% [id, side, hand.distance_to(mote)])
	ok(clips.proc_w <= 0.0 and z[1] - z[0] >= STRIDE_MIN, "%s: the legs play the run under it (%.2f m of stride)"
			% [id, z[1] - z[0]])
	var spark: Node3D = H._spark
	ok(spark.position.distance_to(mote) < SPARK_LAG and spark.scale.x < 0.5, "%s: the Heartspark rides the hand" % id)
	var fired := [false]
	P.inp["fire"] = true
	await _step(m, FIRE_S, func(): fired[0] = fired[0] or P.idle_fire < 0.2 or P.fire_cd > 0.0)
	P.inp["fire"] = false
	await _step(m, FIRE_S, func(): fired[0] = fired[0] or P.idle_fire < 0.2 or P.fire_cd > 0.0)
	ok(fired[0] and H.state == Heart.S.CARRIED, "%s: LMB still fires with the Heartspark" % id)
	_end_kit_move(P)
	await _step(m, SETTLE_S)
	for how in ["hand-off", "knock", "extract"]:
		_take(H, P)
		_end_kit_move(P)
		await _step(m, SETTLE_S)
		ok(clips.heart_w >= 1.0, "%s: carrying again (%s)" % [id, how])
		match how:
			"hand-off":
				H._drop(P.pos)
				H._apply_carrier()
			"knock":
				P.downed = true
			"extract":
				P.downed = false
				P.extracted = true
		await _step(m, SETTLE_S)
		ok(clips.heart_w <= 0.0 and not P.model.has_meta(WardenCarry.MOTE),
				"%s: the layer drops cleanly on %s (weight %.2f)" % [id, how, clips.heart_w])
		P.downed = false
		P.extracted = false
		P.out = false
	m.queue_free()

## P holds the Heartspark (the host's pick, with the slow meta the carry layer reads set at once).
func _take(H: Heart, P: Hunter) -> void:
	H.charge = Heart.r("charge_s")
	H.carrier = P
	H._force(Heart.S.CARRIED, "check")
	H._apply_carrier()

## Meeko and Neve's kits (play_soft) never clear a finished shot move, and a "lead" clip holds its last frame until
## something else plays, so after the volley the held pose would keep the layer off for the rest of the check. The
## match has the same thing in play; this just lets the move end, as a later move would (see the READY note).
func _end_kit_move(P: Hunter) -> void:
	if P.ak != null:
		P.ak.anim_id = ""
	P.anim_s.erase("kmove")      # (the state dict is refilled, not rebuilt)
