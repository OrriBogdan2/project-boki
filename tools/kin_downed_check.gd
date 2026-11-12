extends RefCounted
## --kin-downed-check: a knocked-out Boki lies down and gets up (KinPuppet for primitive bodies, BokiRig for rigged).
##   1. Kin.render puts "kstate" faint on the model while it is downed (not "dazed") and takes it off on a rescue
##   2. every body plan (quad, biped, flyer, serpent, blob), each rigged species: the pose is entered within
##      ENTER_S, eyes shut, flatter than standing, breathing slowly; it tumbles onto its side the way the last hit
##      pushed it (KinFaint) with one bounce and lies there HOLD_S; and left after the revive, with a spring up
##   3. a hit writes plain metas, never a Dictionary (KinFlinch.hit allocates nothing)
## Never touches the save.

const STEP := 1.0 / 60.0
const ENTER_S := 0.2         # s: the pose is in by then
const LEAVE_S := 0.3         # s: and out again by then after a revive
const HOLD_S := 3.0          # s it is followed lying down
const MIN_BOUNCE := 0.6      # share of KinFaint.BOUNCE_M the landing must lift it
const PLANS := {"quad": "cindle", "biped": "zapple", "flyer": "wisplet", "serpent": "zephyrak", "blob": "basaltoad"}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINDOWNED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	_wiring(main)
	BokiRig.enabled = false
	for plan in PLANS:
		_species(main, PLANS[plan], "plan " + plan)
	BokiRig.enabled = true
	for sp in BokiRig.FRAME:
		_species(main, sp, "rigged " + sp)
	print("KINDOWNED DONE, failures: ", bad)
	main.get_tree().quit()

## Kin.render's metas: down while downed, never dazed; gone again after the rescue.
func _wiring(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	var k: Kin = m.player.kin
	k.state = "active"
	k.render(STEP, 1.0)
	ok(String(k.model.get_meta("kstate", "")) != "faint", "an active Boki is not knocked out")
	k.go_down()
	k.render(STEP, 1.0)
	var dazed: bool = k.model.get_meta("dazed", false)
	ok(String(k.model.get_meta("kstate", "")) == "faint" and not dazed, "a downed Boki is faint, not dazed")
	KinDowned.rescue(k)
	k.render(STEP, 1.0)
	ok(String(k.model.get_meta("kstate", "")) != "faint", "a rescued Boki is no longer faint")
	m.queue_free()

func _species(main: Node, species: String, label: String) -> void:
	var model := Models.kin(species)
	main.add_child(model)
	var pup: KinPuppet = null
	var rig: BokiRig = null
	for n in model.get_children():
		if n is KinPuppet: pup = n
	var flex := model.get_node("Body/Flex")
	for n in flex.get_children():
		if n is BokiRig: rig = n
	pup.set_process(false)
	if rig:
		rig.set_process(false)
	_step(model, pup, rig, 0.6)
	KinFlinch.hit(model, Vector3.LEFT, 0.1, 1.0)       # the hit that knocks it out shoves it to its left
	ok(not model.has_meta("hit") and KinFlinch.count(model) == 1, "%s: a hit writes plain metas" % label)
	_step(model, pup, rig, 0.4)
	var stand_y: float = flex.scale.y
	model.set_meta("kstate", "faint")
	_step(model, pup, rig, ENTER_S)
	var wide := rig == null
	ok(pup.down_k > 0.9, "%s: pose entered within %.1fs (down_k %.2f)" % [label, ENTER_S, pup.down_k])
	if wide:
		var low: bool = flex.scale.y < stand_y * 0.95
		ok(low, "%s: lies flatter than it stood (%.2f -> %.2f)" % [label, stand_y, flex.scale.y])
		var eye := flex.get_node_or_null("EyeL") as Node3D
		ok(eye == null or eye.scale.y < 0.2, "%s: eyes shut" % label)
	else:
		var slow: bool = rig.clip in ["settle", "nap"] and rig.player.speed_scale < 1.0
		ok(slow, "%s: settle/nap clip, slowed (%s x%.1f)" % [label, rig.clip, rig.player.speed_scale])
		ok(rig._want.has("closed"), "%s: eyes shut" % label)
	_tumble(model, pup, rig, label)
	model.set_meta("kstate", "")
	for i in 16:       # the puppet skips frames while it is off screen: step until it has run once
		_step(model, pup, rig, STEP)
		if pup.getup_k > 0.0 or (rig and rig.clip == "hop"):
			break
	if rig:
		ok(rig.clip == "hop", "%s: springs up with the hop clip (%s)" % [label, rig.clip])
	else:
		ok(pup.getup_k > 0.3, "%s: spring on getting up (%.2f)" % [label, pup.getup_k])
	_step(model, pup, rig, LEAVE_S)
	ok(pup.down_k < 0.1, "%s: pose left within %.1fs of the revive (down_k %.2f)" % [label, LEAVE_S, pup.down_k])
	var f: KinFaint = rig._faint if rig else pup.faint
	ok(absf(f.roll) < 0.1, "%s: back on its feet within %.1fs (roll %.2f)" % [label, LEAVE_S, f.roll])
	if rig:
		_step(model, pup, rig, 0.1)       # the hop is GETUP_S long, then the idle clip
		ok(rig.clip == "idle", "%s: back to idle (%s)" % [label, rig.clip])
	model.queue_free()

## Down already ENTER_S: it lands on its left side with one bounce, then lies still with its eyes shut.
func _tumble(model: Node3D, pup: KinPuppet, rig: BokiRig, label: String) -> void:
	var f: KinFaint = rig._faint if rig else pup.faint
	var flex := model.get_node("Body/Flex") as Node3D
	var peak := 0.0
	while not f.lying():
		_step(model, pup, rig, STEP)
		if f.roll > 0.0 and absf(f.roll) >= float(KinFaint.ROLL[f.plan]) * 0.85:
			peak = maxf(peak, f.shove.y)
	var lie := float(KinFaint.ROLL[f.plan])
	ok(f.roll > lie * 0.95 and flex.rotation.z > lie * 0.8,
			"%s: tumbled onto its left side, away from the hit (roll %.2f of %.2f)" % [label, flex.rotation.z, lie])
	var bounce := peak - f.shove.y
	ok(bounce >= KinFaint.BOUNCE_M * MIN_BOUNCE, "%s: one bounce on landing (%.3f m)" % [label, bounce])
	var at := flex.rotation.z
	_step(model, pup, rig, HOLD_S)
	ok(absf(flex.rotation.z - at) < 0.05 and model.get_meta("kstate") == "faint",
			"%s: still lying there after %.0fs (roll %.2f)" % [label, HOLD_S, flex.rotation.z])
	var shut := rig._want.has("closed") if rig else (flex.get_node_or_null("EyeL") == null
			or (flex.get_node("EyeL") as Node3D).scale.y < 0.2)
	ok(shut, "%s: eyes still shut" % label)

func _step(model: Node3D, pup: KinPuppet, rig: BokiRig, secs: float) -> void:
	for i in maxi(1, int(round(secs / STEP))):
		pup._process(STEP)
		if rig:
			rig._process(STEP)
