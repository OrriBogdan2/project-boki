extends "res://tools/breah_shots.gd"
## --combo51-shots --shots-dir=<dir> --combo51-hero=archer|mage|dolm: owner item 51's new combos for Pin,
## Vireo and Breah as strips (the Breah rig's 3-wide grid of crops round the hero, tools/breah_shots.gd) in a
## live Arena match, under xvfb with a renderer. <dir>/captions.txt gets "file: caption" per file.

var part := ""                 # --combo51-part=<name>: another set of strips for the hero (the audit's)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--combo51-hero="):
			who = arg.substr(15)
		if arg.begins_with("--combo51-part="):
			part = arg.substr(15)
	hero_name = Arch.name_of(who).to_lower()
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await Callable(self, "_%s" % (part if part != "" else who)).call()
	_write_captions()
	print("COMBO51SHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## Pin: the draw held through the roll, then let go; the draw held through a jump and an air flick, let go up there.
func _archer() -> void:
	var K: ArcherKit = P.ak
	await _reset(9.0)
	var hold := func(t: float):
		K.res = 0.0              # (no Focus: a full Focus is drawn at once)
		P.inp["fire"] = t < 1.0
		if t >= 0.4 and t < 0.4 + DT:
			P.do_dash()
	var marks := _strip(
		"combo_draw_roll_strip",
		"Pin (item 51): drawing; Shift mid-draw, the roll goes at once with the draw kept; still rolling, the"
			+ " reticle charging on; out of the roll, still drawn; let go, the arrow leaves; the follow-through",
		[0.3, 0.45, 0.52, 0.7, 1.03, 1.15]
	)
	await _go(1.4, hold, marks)
	await _reset(9.0)
	var air := func(t: float):
		K.res = 0.0
		P.inp["fire"] = t < 0.75
		P.inp["jump"] = t >= 0.3 and t < 0.3 + DT
		P.inp["move"] = Vector2(1, 0) if t >= 0.3 else Vector2.ZERO
		if t >= 0.5 and t < 0.5 + DT:
			P.do_dash()
	var air_marks := _strip(
		"combo_draw_jump_flick_strip",
		"Pin (item 51): drawing; a jump with the draw held; the air flick with it still held; let go in the air,"
			+ " the arrow leaves and she carries on with her speed; landing",
		[0.25, 0.4, 0.58, 0.78, 0.9, 1.2]
	)
	await _go(1.4, air, air_marks)

## Vireo: Kitefall's crouch into a Wirerun, then the launch from where it ended; the crouch into a jump.
func _mage() -> void:
	P.lvl = 6
	await _reset(9.0)
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	var shift := func(t: float):
		P.inp["dash"] = t >= 0.05 and t < 0.05 + DT
		P.inp["dash_down"] = t >= 0.05 and t < 0.35
	var marks := _strip(
		"combo_kitefall_shift_strip",
		"Vireo (item 51): Kitefall's crouch; Shift in it charges the Wirerun at once; the streak; out of it the"
			+ " crouch starts over; she launches from where the run ended; up, the ring round the new spot",
		[0.03, 0.2, 0.42, 0.62, 0.8, 1.0]
	)
	await _go(1.1, shift, marks)
	await _go(2.4)
	await _reset(9.0)
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)
	var jump := func(t: float): P.inp["jump"] = t >= 0.05 and t < 0.05 + DT
	var jmarks := _strip(
		"combo_kitefall_jump_strip",
		"Vireo (item 51): Kitefall's crouch; a jump in it goes at once; the crouch finishing mid-jump; the launch"
			+ " from that height (no drop first); climbing; hanging",
		[0.03, 0.12, 0.25, 0.36, 0.5, 0.75]
	)
	await _go(0.8, jump, jmarks)
	await _go(2.2)

## Breah: the Quake Fist held through a jump and her air dash, let go as the dash ends.
func _dolm() -> void:
	await _reset(9.0)
	var hold := func(t: float):
		P.inp["fire"] = t < 0.75
		P.inp["jump"] = t >= 0.35 and t < 0.35 + DT
		P.inp["move"] = Vector2(1, 0) if t >= 0.35 else Vector2.ZERO
		if t >= 0.5 and t < 0.5 + DT:
			P.ex_cd = 0.0
			P.do_dash()
	var marks := _strip(
		"combo_fist_jump_dash_strip",
		"Breah (item 51): the Quake Fist charging; a jump with it held; her air dash, the charge kept; let go in"
			+ " the dash; the punch as it ends, in the air, still carried forward; landing",
		[0.3, 0.42, 0.58, 0.72, 0.8, 1.1]
	)
	await _go(1.3, hold, marks)

## The audit (Nov 3): Skycall held and dragged, then released; the strike ring at its true radius.
func _mage_audit() -> void:
	await _reset(7.0)
	P.ak.cd["e"] = 0.0
	_aim(T.pos)
	P.inp["e_down"] = true
	P.ak.use_e()
	var drag := func(t: float):
		_aim(T.pos + Vector3(-3.0 * minf(1.0, t / 0.4), 0, 0))
		P.inp["e_down"] = t < 0.6
	var at_t := func(): return T.position + Vector3(0, 0.9, 0)
	var marks := [
		[0.45, "full", "audit_skycall_held", "Vireo Skycall held (audit: the data's hold, drag, release): the drag"
			+ " arrow follows the cursor back toward her, the rim chevron points it; nothing commits while E is held",
			at_t],
		[0.9, "full", "audit_skycall_count", "Released at 0.6s: committed, the pillar narrows over the 0.8s countdown",
			at_t],
		[1.42, "full", "audit_skycall_strike", "The strike: its ring drawn at the 1.5m hit radius, no longer 2.3m;"
			+ " the target slid toward her with 1 Static", at_t],
	]
	await _go(2.2, drag, marks)
	P.inp["e_down"] = false

## The audit (Nov 3; the owner's 23:55 answer): an ally jumps against Tarek's rock and is lifted onto it.
func _dolm_audit() -> void:
	await _reset(9.0)
	_aim(home + Vector3(5.0, 0, 0))
	P.ak.cd["e"] = 0.0
	P.ak.use_e()
	await _go(0.5)
	var ally: Hunter = m.make_hunter("A", P.team, "medium", "Ally", "idle", {}, home, {"arch": "none"})
	T2 = ally                      # (the rig parks every other hunter far off)
	P.teleport(home + Vector3(-2.0, 0, -3.0))
	var hop := func(t: float):
		ally.inp["move"] = Vector2(1, 0)
		ally.inp["jump"] = t >= 0.45 and t < 0.45 + DT
	var marks: Array = []
	for tt in [0.3, 0.5, 0.62, 0.75, 0.9, 1.2]:
		var cap := "Tarek's rock (per the data and the owner): an ally walks into it and is stopped; jumps against"
		cap += " it; is lifted onto the top; walks over and drops off"
		var on_ally := func(): return ally.pos + Vector3(0, 0.9, 0)
		marks.append([tt, "audit_ally_hop_strip", "audit_ally_hop_strip", cap, on_ally])
	await _go(1.4, hop, marks)
	T2 = null
	ally.queue_free()
	m.hunters.erase(ally)
