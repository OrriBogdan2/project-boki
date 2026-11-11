extends "res://tools/archetype_check.gd"
## --recast-cue-shots --shots-dir=<dir>: RecastCue's review screenshots (run under a renderer, jobq --needs gpu).
## Hunters mid-recast (Sparkle's knife, Motley's hang, Mossy's hammer, Sable's seed), a Dazed foe, EXPIRED and
## the payoff flash; full frames as recast_<name>.png. The match is paused (set_process off) so each frame holds
## the moment.

var dir := ""

func _grab(file: String) -> void:
	for i in 6:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("recast_%s.png" % file))
	print("RECASTSHOT ", file)

func _scene(hero: String) -> Array:
	var s := setup(hero, 6.0)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = s[1]
	P.ak.cd["e"] = 0.0
	return s

## Steps until `slot`'s window is open, then `extra` seconds more.
func _until(m: Match, P: Hunter, slot: String, extra: float) -> void:
	var t := 0.0
	while String(P.ak.recast_window().get("slot", "")) != slot and t < 4.0:
		m.step(DT)
		t += DT
	step(m, extra)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	# Sparkle (thief): the knife stuck by the foe, "E AGAIN" and the marker on the knife; Marks on the foe
	var s := await _scene("thief")
	var m: Match = s[0]
	var P: Hunter = s[1]
	var T: Hunter = s[2]
	(P.ak as ThiefKit).add_mark(T, 3, true)
	aim_at(P, T.pos + Vector3(-1.5, 0, 1.5))
	P.ak.use_e()
	await _until(m, P, "e", 0.3)
	await _grab("thief_knife")
	RecastCue.payoff(P.ak, T)
	(P.ak as ThiefKit)._reset_fx(T)
	step(m, 0.08)
	await _grab("thief_payoff_flash")
	await done(m)
	# Motley (mage): Kitefall's hang, "X AGAIN" on the ult tile and the marker on the landing spot; Sparks
	s = await _scene("mage")
	m = s[0]
	P = s[1]
	T = s[2]
	(P.ak as MageKit).sparks[T.get_instance_id()] = {"e": T, "n": int(P.ak.res_def()["max"]), "t": 3.0}
	aim_at(P, T.pos)
	P.ak.cast_ult()
	await _until(m, P, "x", 0.6)
	await _grab("mage_hang")
	await done(m)
	# Mossy (bulwark): the hammer out, "LMB AGAIN" on the weapon card and the marker on the hammer
	s = await _scene("bulwark")
	m = s[0]
	P = s[1]
	T = s[2]
	aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(DT)
	P.inp["fire"] = false
	await _until(m, P, "lmb", 0.5)
	await _grab("bulwark_hammer")
	await done(m)
	# Sable (ostra): the seed's 0.3s WAIT, then the late window (hot ring, ticks), then EXPIRED
	s = await _scene("ostra")
	m = s[0]
	P = s[1]
	T = s[2]
	aim_at(P, T.pos)
	P.ak.use_e()
	await _until(m, P, "e", 0.0)
	await _grab("ostra_wait")
	step(m, P.ak.e_t - 0.4)
	await _grab("ostra_closing")
	step(m, 0.6)
	await _grab("ostra_expired")
	await done(m)
	# Vex (gunslinger): a Dazed foe's badge (what it is, the ring of time left)
	s = await _scene("gunslinger")
	m = s[0]
	P = s[1]
	T = s[2]
	(P.ak as GunslingerKit).daze(T, 3.0)
	step(m, 0.8)
	await _grab("gunslinger_dazed")
	await done(m)
	main.get_tree().quit(0)
extends RefCounted
## --recast-cue-shots --shots-dir=<dir>: the "<KEY> AGAIN" cue (scripts/ui/recast_cue.gd) in a live match HUD for three
## Hunters: Thief (E), Cinder (X), Albert (the hammer, LMB). One bottom-left HUD crop each.
## Needs a renderer (jobq --needs gpu).

const SHOTS := [
	["thief", "thief_e", "Shadow Knife stuck: E AGAIN on the E slot"],
	["ashwick", "ashwick_x", "Flue Flight: X AGAIN, ring shrinking with the flight"],
	["bulwark", "bulwark_lmb", "Hammer out: LMB AGAIN on a tile over the RMB slot"],
]
const CROP := Rect2i(0, 520, 760, 200)      # px of the viewport round the ability bar

var main: Node
var dir := "/tmp/recast_cue_shots"

	for s in SHOTS:
		await _shot(String(s[0]), String(s[1]))
	print("RECASTSHOTS %d in %s" % [SHOTS.size(), dir])

func _shot(arch: String, file: String) -> void:
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts(arch), true)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P.lvl = 6
	P.slot_lv["ult"] = 1
	var K: ArchKit = P.ak
	P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
	P.inp["aim_y"] = P.pos.y
	match arch:
		"thief": K.use_e()
		"ashwick":
			K.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		"bulwark":
			P.inp["fire"] = true
			for i in 6: m.step(1.0 / 60.0)
			P.inp["fire"] = false
	for i in 40:
		m.step(1.0 / 60.0)
		P.inp["aim"] = P.pos + Vector3(8, 0.9, 0)
	print("RECASTSHOTS %s left %.2f slot %s text '%s'" % [arch, K.recast_left(), K.recast_slot(), RecastCue.shown])
	var rg := CROP.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rg).save_png(dir.path_join(file + ".png"))
	img.save_png(dir.path_join(file + "_full.png"))
	m.queue_free()
	await main.get_tree().process_frame
