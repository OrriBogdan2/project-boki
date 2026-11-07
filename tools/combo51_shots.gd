extends "res://tools/breah_shots.gd"
## --combo51-shots --shots-dir=<dir> --combo51-hero=<id>: owner item 51's new combos as strips (the Breah
## rig's 3-wide grid of crops round the hero, tools/breah_shots.gd) in a live Arena match, under xvfb with a
## renderer: archer|mage|dolm (Lisette, Sparkle, Tarek) and juggernaut|dredge|ashwick (Kael, Grimble, Cinder).
## <dir>/captions.txt gets "file: caption" per file.
## --combo51-part=<part> takes `_<hero>_<part>` instead: "audit" (Sparkle, Tarek: the audit's strips) or Kael's
## "chain" (the Warchain's tether and pull, on a map island long enough for its 24 m: LONG_PARTS), or Cinder's
## "item66" (LMB held through Flue Flight) or "queen" (the Flame Queen: LMB from her hands, Flue Flight's fire).

const LONG := 30                # m of flat ground the chain strips need, east of the spot
const LONG_PARTS := ["chain"]   # parts shot on an expedition map instead of the Arena

var part := ""                 # --combo51-part=<name>: another set of strips for the hero (`_<hero>_<part>`)

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
	hero_name = Arch.bare_title(who).to_lower()
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	await Callable(self, "_%s" % (who if part == "" else who + "_" + part)).call()
	_write_captions()
	print("COMBO51SHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## Lisette: the draw held through the roll, then let go; the draw held through a jump and an air flick, let go up there.
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
		"Lisette (item 51): drawing; Shift mid-draw, the roll goes at once with the draw kept; still rolling, the"
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
		"Lisette (item 51): drawing; a jump with the draw held; the air flick with it still held; let go in the air,"
			+ " the arrow leaves and she carries on with her speed; landing",
		[0.25, 0.4, 0.58, 0.78, 0.9, 1.2]
	)
	await _go(1.4, air, air_marks)

## Sparkle: Kitefall's crouch into a Wirerun, then the launch from where it ended; the crouch into a jump.
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
		"Sparkle (item 51): Kitefall's crouch; Shift in it charges the Wirerun at once; the streak; out of it the"
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
		"Sparkle (item 51): Kitefall's crouch; a jump in it goes at once; the crouch finishing mid-jump; the launch"
			+ " from that height (no drop first); climbing; hanging",
		[0.03, 0.12, 0.25, 0.36, 0.5, 0.75]
	)
	await _go(0.8, jump, jmarks)
	await _go(2.2)

## Sparkle items 71-73: the committed Skycall arrow, an orb pulled to her (the flash), Kitefall's Static arcs.
func _mage_items() -> void:
	var K: MageKit = P.ak
	var at_t := func(): return T.position + Vector3(0, 0.9, 0)
	await _reset(7.0)
	_aim(T.pos)
	P.inp["e_down"] = true
	K.use_e()
	var drag := func(t: float):
		_aim(T.pos + Vector3(-2.2, 0, 2.6))
		P.inp["e_down"] = t < 0.4
	var caption := "Item 73: Skycall committed to a diagonal drag: the arrow in the circle is the exact push"
	await _go(1.3, drag, [[0.9, "full", "items_skycall_arrow", caption, at_t]])
	await _reset(25.0)
	P.dashes = 0.0
	var spot := home + Vector3(6, 0, 0)
	K.motes.clear()
	K.motes.append({"pos": spot, "t": 6.0, "node": K.own_node(), "owner": T})
	_aim(spot)
	P.inp["e_down"] = true
	K.use_e()
	var pull := func(t: float):
		_aim(home + Vector3(2.0, 0, 0))
		P.inp["e_down"] = t < 0.4
	var pickup := "Item 71: the orb dragged toward her flew to her: the flash and chime, Wirerun back"
	await _go(1.8, pull, [[1.5, "full", "items_orb_pulled", pickup, Callable()]])
	await _reset(7.0)
	var beside := T.pos + Vector3(1.4, 0, 1.0)
	var T2b: Hunter = m.make_hunter("T2", 5, "medium", "Target2", "idle", {}, beside, {"arch": "none"})
	T2b.max_hp = 10000.0
	T2b.hp = T2b.max_hp
	T2 = T2b
	K.add_spark(T, 3)
	K.cd["x"] = 0.0
	P.lvl = 6
	HunterKeys.ult_pressed(P)
	var ult := func(t: float):
		_aim(T.pos)
		if t >= 0.9 and t < 0.9 + DT:
			HunterKeys.ult_pressed(P)
	var arcs := "Item 72: Kitefall on a foe with 3 Static: lightning arcs to the other, both raised to 4"
	await _go(1.6, ult, [[1.13, "full", "items_ult_spread", arcs, at_t]])
	T2 = null
	T2b.queue_free()
	m.hunters.erase(T2b)

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

## The long parts' rig: an expedition map (the Arena's islands are too small for the chain), the spot on a flat run of
## LONG m.
func _setup() -> void:
	if not LONG_PARTS.has(part):
		await super._setup()
		return
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"arch": who, "cls": Arch.weight(who), "weapon": Arch.signature(who)}
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _long_spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T:
			x.teleport(home + Vector3(-30, 0, 30))
	P.unlock_all()
	P.lvl = 6
	if m.hud: m.hud.guide_hidden = true       # (the kit panel would sit over the chain)
	await _reset(7.0)

func _long_spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(8, W.h - 8, 2):
		for x in range(12, W.w - LONG - 4, 2):
			if _run_flat(W, x, z):
				return Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	return start

func _run_flat(W, x: int, z: int) -> bool:
	var lv: int = int(W.level[W.idx(x, z)])
	for dz in range(-3, 4):
		for dx in range(-10, LONG):
			var i: int = W.idx(x + dx, z + dz)
			var odd: bool = W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i)
			if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or odd:
				return false
	return true

## The step at `when` s into a _go (t steps by DT, so an exact float window can be skipped).
func _at(t: float, when: float) -> bool:
	return absf(t - when) < DT * 0.5

## Kael: the Searing Wave held through the Rampage; the Slam Drive; an air dash in the Meteor Drop's hang.
func _juggernaut() -> void:
	var K: JuggernautKit = P.ak
	await _reset(10.0)
	var wave := func(t: float):
		P.inp["fire"] = t < 1.15
		if _at(t, 0.45):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t >= 0.5:
			P.inp["move"] = Vector2.ZERO
	var marks := _strip(
		"combo_wave_rampage_strip",
		"Kael (item 51): the Searing Wave charging; Shift with it held, the Rampage's crouch; the drive, the"
			+ " charge kept; out of the drive, the wind-up pose back; let go, the wave leaves; the follow-through",
		[0.38, 0.55, 0.72, 0.98, 1.2, 1.4]
	)
	await _go(1.6, wave, marks)
	await _reset(7.5)
	var slam := func(t: float):
		if _at(t, 0.1):
			K.press_rmb()
		if _at(t, 0.25):
			P.do_dash()
	var smarks := _strip(
		"combo_slam_drive_strip",
		"Kael (item 51): the Slam winding up; Shift in it, the Slam Drive goes at once along the strike's aim,"
			+ " the overhead pose kept; driving in; the drive's end; the Slam lands where it arrived; recovery",
		[0.2, 0.3, 0.42, 0.56, 0.76, 0.95]
	)
	await _go(1.2, slam, smarks)
	await _reset(6.0)
	var drop := func(t: float):
		P.inp["jump"] = t < DT
		if _at(t, 0.25):
			K.press_rmb()
		if _at(t, 0.36):
			P.inp["move"] = Vector2(0, 1)
			P.do_dash()
		if t >= 0.4:
			P.inp["move"] = Vector2.ZERO
	var dmarks := _strip(
		"combo_meteor_airdash_strip",
		"Kael (item 51): the Meteor Drop's hang over its marker; Shift, the air dash goes in the gather pose;"
			+ " the dash's end, off to the side; the dive back onto the marker; the impact; the recovery",
		[0.34, 0.42, 0.55, 0.64, 0.76, 1.0]
	)
	await _go(1.3, drop, dmarks)

## Grimble: Shift in the Anchor's wind-up; Shift in the Broadside's charge.
func _dredge() -> void:
	await _reset(8.0)
	var anchor := func(t: float):
		if _at(t, 0.1):
			P.ak.use_e()
		if _at(t, 0.2):
			P.do_dash()
	var marks := _strip(
		"combo_anchor_barge_strip",
		"Grimble (item 51): the Anchor's wind-up, fist raised; Shift in it, the barge goes at once with the fist"
			+ " still up; arriving; the slam lands where he arrived; the dust; recovery",
		[0.16, 0.24, 0.34, 0.5, 0.62, 0.85]
	)
	await _go(1.1, anchor, marks)
	P.lvl = 6
	await _reset(8.0)
	var blast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		if _at(t, 0.5):
			P.inp["move"] = Vector2(0, 1)
			P.do_dash()
		if t >= 0.55:
			P.inp["move"] = Vector2.ZERO
	var bmarks := _strip(
		"combo_broadside_barge_strip",
		"Grimble (item 51): the Broadside charging behind its fan; Shift, the barge goes at once in the bracing"
			+ " pose; arrived, the fan has followed him; the first wave; the second wave; done",
		[0.4, 0.56, 0.8, 1.25, 1.85, 2.1]
	)
	await _go(2.3, blast, bmarks)

## Cinder: the lance held through a ram; Shift in the flight; a jump off the flight.
func _ashwick() -> void:
	P.lvl = 6
	await _reset(11.0)
	var lance := func(t: float):
		P.inp["fire"] = t < 1.4
		if _at(t, 0.6):
			P.do_dash()
	var marks := _strip(
		"combo_lance_ram_strip",
		"Cinder (item 51): the lance roaring; Shift with it held, the ram goes and the stream goes out; still"
			+ " ramming; the ram's end, the stream back at once (no pilot, no gap); roaring on; let go",
		[0.5, 0.66, 0.78, 0.94, 1.15, 1.5]
	)
	await _go(1.6, lance, marks)
	await _reset(14.0)
	P.teleport(home + Vector3(-5.0, 0, 0))      # (room on the island for the boosted flight)
	var poof := func(t: float):
		if (_at(t, 0.1)) or (_at(t, 0.8)):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)        # (the second press lands early, still over the island)
		P.inp["dash"] = _at(t, 0.55)
		P.inp["move"] = Vector2(1, -0.4).normalized() if t >= 0.55 and t < 0.6 else Vector2.ZERO
	var pmarks := _strip(
		"combo_flight_poof_strip",
		"Cinder (item 51): flying over the carpet; Shift, a poof from the bellows (the air dash spent); the"
			+ " flight faster and bent its way; flying on; X again, landing; on foot, the carpet behind",
		[0.4, 0.58, 0.66, 0.74, 0.86, 1.1]
	)
	await _go(1.25, poof, pmarks)
	await _reset(14.0)
	var leap := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		P.inp["jump"] = (_at(t, 0.7)) or (_at(t, 0.95))
		P.inp["glide"] = t >= 0.95
	var lmarks := _strip(
		"combo_flight_leap_strip",
		"Cinder (item 51): flying; a jump leaps off the jet, its speed kept; rising; the glider opens with the"
			+ " flight's speed; gliding on; the carpet left behind",
		[0.6, 0.76, 0.88, 1.05, 1.3, 1.6]
	)
	await _go(1.7, leap, lmarks)

## Cinder, owner item 66 (--combo51-part=item66): LMB held from before the cast to after the landing. She weaves so
## the flight stays over the island, and the camera follows her.
func _ashwick_item66() -> void:
	var K: AshwickKit = P.ak
	P.lvl = 6
	await _reset(4.0)
	var held := func(t: float):
		P.inp["fire"] = true
		if _at(t, 0.7):
			K.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		if K.jet.running():
			var d: Vector2 = (K.jet.flight["dir"] as Vector2).rotated(1.7 if fmod(t, 1.0) < 0.5 else -1.7)
			P.inp["aim"] = P.pos + Vector3(d.x * 6.0, 0.9, d.y * 6.0)
		else:
			P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	var marks := _strip(
		"item66_lmb_held_strip",
		"Cinder (item 66), LMB held throughout: the lance roaring; lift-off, the stream goes out; flying, no"
			+ " flame and no pilot, the carpet behind; still flying, still held; the frame after the flight, the"
			+ " cyan pilot lights; the lance roars again",
		[0.6, 0.8, 1.5, 2.4, 2.56, 2.95]
	)
	await _go(3.1, held, marks)

## Cinder, Flame Queen (--combo51-part=queen): the LMB stream from her hands, and Flue Flight with fire from her heels
## and tail (briefs DECISIONS "Cinder the Flame Queen").
func _ashwick_queen() -> void:
	var K: AshwickKit = P.ak
	P.lvl = 6
	await _reset(6.0)
	var held := func(t: float):
		P.inp["fire"] = t < 1.2
		P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	var hmarks := _strip(
		"queen_lmb_hands_strip",
		"Cinder the Flame Queen: standing; LMB, the fire starts at her hand; the stream building; full stream;"
			+ " the stream roaring; let go; the last embers",
		[0.1, 0.35, 0.6, 0.9, 1.25, 1.5]
	)
	await _go(1.6, held, hmarks)
	await _reset(14.0)
	var lift := func(t: float):
		if _at(t, 0.1):
			K.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
	var umarks := _strip(
		"queen_flue_flight_strip",
		"Cinder the Flame Queen, Flue Flight: standing; X, the lift-off, fire from her heels and tail; rising;"
			+ " flying; flying on; the landing",
		[0.05, 0.3, 0.6, 1.0, 1.6, 2.4]
	)
	await _go(2.6, lift, umarks)

## Kael's Warchain, as whole views (the chain is longer than a strip crop): it pays out as he backs away and
## holds taut at 24 m; backing away then pulling slingshots him in; a strafe held in the pull curves him in beside.
func _juggernaut_chain() -> void:
	var K: JuggernautKit = P.ak
	await _reset(-8.0)
	var taut := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		P.inp["move"] = Vector2(1, 0) if t > 0.4 else Vector2.ZERO
		_aim(T.pos)
	await _go(4.9, taut, [
		[0.45, "full", "warchain_taut_1", "Kael Warchain: hooked on the dummy 8 m away, he starts backing off"],
		[2.6, "full", "warchain_taut_2", "Kael Warchain: ~17 m, the chain paying out after him"],
		[4.6, "full", "warchain_taut_3", "Kael Warchain: at 24 m it is taut and hot and holds: he keeps walking but"
				+ " stays at its end"]], -9.0)
	K.warchain.snap("")
	await _reset(9.0)
	var sling := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		P.inp["move"] = Vector2(-1, 0) if t > 0.45 and t < 1.0 else Vector2.ZERO
		if _at(t, 0.95):
			K.use_e()
		_aim(T.pos)
	await _go(1.5, sling, [
		[0.9, "full", "warchain_sling_1", "Kael Warchain: hooked, backing away"],
		[1.07, "full", "warchain_sling_2", "Kael Warchain: E while backing away: the slingshot, flying in faster"],
		[1.25, "full", "warchain_sling_3", "Kael Warchain: arrived on the dummy, still moving"]], 4.5)
	cam_at = home + Vector3(6.5, 0, -2.0)      # item 57: both hauls under one still camera, to lay over each other
	for run in [["straight", Vector3(13, 0, 0)], ["curved", Vector3(0, 0, -13)]]:
		await _haul_strip(String(run[0]), run[1])
	cam_at = Vector3.ZERO

## A haul at the dummy 13 m east: hooked with the cursor on it, then the cursor at `look` from him (it stays put
## on screen) as E is pressed.
func _haul_strip(name_of_run: String, look: Vector3) -> void:
	var K: JuggernautKit = P.ak
	await _reset(13.0)
	var haul := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.use_e()
		if _at(t, 0.8):
			K.use_e()
		_aim(T.pos if t < 0.6 else P.pos + look)
	var marks := []
	for i in 7:
		var when := 0.75 + 0.12 * i
		marks.append([when, "full", "haul_%s_%d" % [name_of_run, i],
				"Kael Warchain, %s haul, %.2f s after the press" % [name_of_run, when - 0.8]])
	await _go(1.65, haul, marks)
	K.warchain.snap("")

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
		[0.45, "full", "audit_skycall_held", "Sparkle Skycall held (audit: the data's hold, drag, release): the drag"
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
