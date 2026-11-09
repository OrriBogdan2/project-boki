extends RefCounted
## --pin-bjorn-shots --shots-dir=<dir> [--before]: screenshots of Lisette's and Breaker's abilities, run
## through the real kits with scripted input on a flat stretch of island (xvfb, a renderer). Each shot is
## [file stem, hero, script, capture time s, camera lead m east, caption]. Writes <dir>/MANIFEST.txt as
## `<hero>/v2|<file>|<caption>`. --before runs only the "before/after" set, touching nothing but input
## and the dummy, so the same file can be dropped into an older checkout for the "before" frames.

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var dir := ""
var home := Vector3.ZERO
var lines: Array = []
var before := false
var crush_rock := Vector3.INF     # the rock the "crush" shot drives the dummy into
const DT := 1.0 / 60.0
## the camera's zoom for the close-up of each shot (1.0 is the default gameplay zoom)
const CLOSE_ZOOM := 0.45

const SHOTS := [
	# ------------------------------------------------ Lisette
	[
		"pin_draw_idle",
		"archer",
		"aim",
		0.3,
		3.0,
		"At rest: one faint thin line to the cursor, nothing else"
	],
	[
		"pin_draw_start",
		"archer",
		"draw",
		0.2,
		3.0,
		"The thin line to the cursor, the bright fill just growing out of Lisette, the small circle ahead of it"
	],
	[
		"pin_draw_mid",
		"archer",
		"draw",
		0.5,
		3.0,
		"The fill most of the way to the circle (the circle still quiet)"
	],
	[
		"pin_draw_empowered",
		"archer",
		"draw",
		0.64,
		3.0,
		"The fill has reached the circle and the circle flashes: release now for the perfect shot"
	],
	[
		"pin_draw_next",
		"archer",
		"draw",
		0.95,
		3.0,
		"Past the perfect window: the circle has moved on to the end of the line, the fill running on toward it"
	],
	[
		"pin_draw_super",
		"archer",
		"draw_tgt",
		1.3,
		4.0,
		"Supercharged held: the thick white line past the cursor to max range, the dummy ringed at its feet"
	],
	[
		"pin_super_ready",
		"archer",
		"draw_tgt",
		1.18,
		4.0,
		"Supercharged comes up: the body flash, the fill reaching the end circle, the white line past the cursor"
	],
	[
		"pin_quick_draw",
		"archer",
		"quick",
		1.16,
		3.0,
		"Quick draw after a perfect release: the next Empowered comes up in 0.38 s (the fill reaching the circle)"
	],
	[
		"pin_overdraw",
		"archer",
		"draw_tgt",
		1.85,
		4.0,
		"Overdrawn: the line dims to a thin pale one, the draw arm shakes"
	],
	[
		"pin_perfect",
		"archer",
		"perfect",
		0.68,
		2.5,
		"Perfect release: Lisette's gold fletch burst with its ring at the bow, on the aim line (0.13 s)"
	],
	[
		"pin_arrow_flight",
		"archer",
		"empowered_miss",
		0.87,
		3.0,
		"Empowered arrow in flight: a solid green arrow with a teal head and a green trail, heading for the cursor"
	],
	[
		"pin_spent_arrow",
		"archer",
		"empowered_miss",
		1.6,
		3.0,
		"No target: the arrow stuck in the ground at the cursor, glowing teal"
	],
	[
		"pin_super_flight",
		"archer",
		"super_shot",
		1.33,
		4.0,
		"Supercharged arrow: the thick mint-teal bolt and its wide 5 m trail past the cursor"
	],
	[
		"pin_super_hit",
		"archer",
		"super_shot",
		1.43,
		5.0,
		"Supercharged hit: the teal X-star and a mint fletch burst on the dummy"
	],
	[
		"pin_heavy_hold",
		"archer",
		"heavy",
		1.0,
		3.0,
		"Heavy Shot held: the great silver needle on the bow, its red thread trailing, glowing with the charge"
	],
	[
		"pin_heavy_flight",
		"archer",
		"heavy",
		1.27,
		4.0,
		"Heavy Shot: the gold arrow (1.5x) with violet fins and a gold trail, the pink crescent at her feet"
	],
	[
		"pin_heavy_hit",
		"archer",
		"heavy",
		1.4,
		5.0,
		"Heavy Shot impact: a red star and red-white burst, dust as the dummy is driven back, the white ring"
	],
	["pin_spirit_roll", "archer", "spirit", 0.6, 2.0, "Spirit Walk: the dodge roll and its green burst"],
	[
		"pin_spirit_inside",
		"archer",
		"spirit_rock",
		1.15,
		1.0,
		"Spirit Walk inside a rock: the green shell, her screen tinted dark blue"
	],
	[
		"pin_hail_tell",
		"archer",
		"hail",
		0.6,
		3.0,
		"Hail Wall cast: the bow raised high, green arrows lobbed up, the curved arc at the cursor distance"
	],
	[
		"pin_hail_rain",
		"archer",
		"hail",
		1.8,
		3.0,
		"Hail Wall: seven green panels with fletch posts, arrows streaking down, blue burn flames on the dummy"
	],
	# ------------------------------------------------ Breaker
	[
		"bjorn_throw_flight",
		"bulwark",
		"throw",
		0.62,
		3.0,
		"Hammer thrown: tumbling, gold-orange glow and trail, flying to the cursor"
	],
	[
		"bjorn_planted",
		"bulwark",
		"throw",
		1.4,
		3.0,
		"Planted at the cursor: standing head-down in the ground (1.5x) under the upright gold beacon ray"
	],
	["bjorn_recall", "bulwark", "recall", 1.62, 3.0, "Recall: the hammer flying back"],
	[
		"bjorn_spin",
		"bulwark",
		"spin",
		0.75,
		1.5,
		"LMB held: side-on and crouched, the hammer whirling round him with its trail, the shield arm forward,"
			+ " the gold ring at his feet"
	],
	[
		"bjorn_glint",
		"bulwark",
		"spin",
		1.25,
		1.5,
		"LMB held past 0.6 s: the gold glint riding the whirling hammer head"
	],
	[
		"bjorn_flare",
		"bulwark",
		"spin",
		1.71,
		1.5,
		"Full charge: the big gold star flare on the hammer head and the cursor flare"
	],
	["o59_spin_a", "bulwark", "spin", 0.68, 1.5, "item 59: strip 1/6, the hammer eases out of the hand"],
	["o59_spin_b", "bulwark", "spin", 0.74, 1.5, "item 59: strip 2/6, the whirl, a quarter turn on"],
	["o59_spin_c", "bulwark", "spin", 0.8, 1.5, "item 59: strip 3/6, the whirl, a quarter turn on"],
	["o59_spin_d", "bulwark", "spin", 1.25, 1.5, "item 59: strip 4/6, faster, the glint on the head"],
	["o59_spin_e", "bulwark", "spin", 1.68, 1.5, "item 59: strip 5/6, full charge, the flash, still whirling"],
	["o59_spin_f", "bulwark", "slam", 1.86, 1.5, "item 59: strip 6/6, the release: the slam forward"],
	[
		"bjorn_slam",
		"bulwark",
		"slam",
		1.86,
		2.0,
		"Release: the flaming 180 degree crescent (2.7 m), carried forward, the body upright"
	],
	[
		"bjorn_slam_hit",
		"bulwark",
		"slam",
		1.9,
		2.5,
		"Slam impact: the damage number and white dust on the dummy, the debris trail"
	],
	[
		"bjorn_aegis",
		"bulwark",
		"aegis",
		0.9,
		1.5,
		"RMB held: his aegis, a solid pale-gold slab with ribs, a bright rim and his hammer sigil"
	],
	[
		"bjorn_aegis_block",
		"bulwark",
		"aegis_block",
		1.1,
		1.5,
		"Aegis blocking: the whole slab flashes, gold sparks off its face"
	],
	[
		"bjorn_aegis_break",
		"bulwark",
		"aegis_break",
		1.14,
		1.5,
		"Aegis broken: gold shards, SHIELD BROKEN, rocked back on his feet"
	],
	[
		"bjorn_smash_dash",
		"bulwark",
		"smash",
		0.6,
		3.0,
		"360 Smash: the hard 0.17 s run-up, upright, the gold chevron wake behind"
	],
	[
		"bjorn_smash_spin",
		"bulwark",
		"smash",
		0.78,
		3.5,
		"360 Smash: the one spin hit, the red-orange-gold spiral ring, sliding on"
	],
	[
		"bjorn_purify_column",
		"bulwark",
		"purify",
		1.05,
		1.0,
		"Mending Ground with the hammer in hand: the green column coming down on him, the ring filling"
	],
	["bjorn_purify_burst", "bulwark", "purify", 1.62, 1.0, "Mending Ground lands: the green ring bloom"],
	[
		"bjorn_crushed",
		"bulwark",
		"crush",
		1.8,
		1.5,
		"Passive payoff: a full Crushing Blow drives the dummy into a rock: CRUSHED, stunned, Breaker healed"
	],
	# ------------------------------------------------ the ultimates on X (MANIFEST under <hero>/v2/ult)
	[
		"ult_pin_telegraph",
		"archer",
		"pin_ult",
		0.7,
		4.0,
		"Starpiercer up: the beam's lane to 18 m, the ticked ring at her feet, three pips"
	],
	[
		"ult_pin_nock",
		"archer",
		"pin_ult",
		0.98,
		4.0,
		"Key frame: the 0.3 s nock, string to the cheek, the bow glowing, the lane filling"
	],
	[
		"ult_pin_impact",
		"archer",
		"pin_ult",
		1.2,
		4.0,
		"Impact: the beam through the target, a white burst cloud and a teal star"
	],
	[
		"ult_pin_final",
		"archer",
		"pin_ult_final",
		1.2,
		4.0,
		"The last beam: a wider beam, a bigger burst, the hard kick"
	],
	[
		"ult_bjorn_telegraph",
		"bulwark",
		"bjorn_ult",
		0.55,
		6.0,
		"Faultline wind-up: four cells to 16 m shown to everyone, the hammer overhead"
	],
	[
		"ult_bjorn_slam",
		"bulwark",
		"bjorn_ult",
		0.73,
		6.0,
		"Key frame: the slam, gold light flooding the near cell, the streak setting off"
	],
	["ult_bjorn_impact", "bulwark", "bjorn_ult", 1.25, 6.0, "Impact: slabs heaving up cell by cell, the target thrown"],
	[
		"ult_bjorn_scar",
		"bulwark",
		"bjorn_ult",
		2.4,
		6.0,
		"After: the ember scar along the lane (10 s, slows foes on it)"
	],
]
## The owner playtest items of 2026-11-03 (--owner1103): captions open with the item number.
const OWNER := [
	[
		"o1103_pin_draw_a",
		"archer",
		"draw_tgt",
		0.07,
		3.0,
		"owner1103 #5: draw strip 1/5, the arrow nocked 0.07 s after the press"
	],
	[
		"o1103_pin_draw_b",
		"archer",
		"draw_tgt",
		0.3,
		3.0,
		"owner1103 #5: draw strip 2/5, the steady pull, the fill growing along the aim line"
	],
	[
		"o1103_pin_draw_c",
		"archer",
		"draw_tgt",
		0.64,
		3.0,
		"owner1103 #5: draw strip 3/5, Empowered ready, the fill on the circle, the circle flashing"
	],
	[
		"o1103_pin_draw_d",
		"archer",
		"draw_tgt",
		0.95,
		4.0,
		"owner1103 #5: draw strip 4/5, the fill running on toward Supercharged"
	],
	[
		"o1103_pin_draw_e",
		"archer",
		"draw_tgt",
		1.3,
		4.0,
		"owner1103 #5: draw strip 5/5, Supercharged, the thick line from Lisette past the cursor"
	],
	[
		"o1103_pin_perfect",
		"archer",
		"perfect",
		0.7,
		2.5,
		"owner1103 #5: the perfect release, the gold flash on the aim line"
	],
	[
		"o1103_pin_heavy_hold",
		"archer",
		"heavy_pin",
		1.0,
		3.0,
		"owner1103 #6: the Heavy Shot held, the thick gold lane from the bow"
	],
	[
		"o1103_pin_heavy_release",
		"archer",
		"heavy_pin",
		1.29,
		3.0,
		"owner1103 #6: the Heavy Shot's release burst on the aim line and the big arrow"
	],
	[
		"o1103_pin_heavy_flight",
		"archer",
		"heavy_pin",
		1.33,
		4.0,
		"owner1103 #6: the Heavy Shot mid-flight, about 3.5 times a normal arrow with a long trail"
	],
	[
		"o1103_pin_heavy_impact",
		"archer",
		"heavy_pin",
		1.5,
		5.0,
		"owner1103 #6: the Heavy Shot on the body: hit flash, pinned against the wall, the stake in it"
	],
	[
		"o1103_pin_heavy_stake",
		"archer",
		"heavy_pin",
		2.6,
		5.0,
		"owner1103 #6: the stake still standing in the wall after the pin"
	],
	[
		"o1103_pin_dash",
		"archer",
		"spirit",
		0.54,
		2.0,
		"owner1103 #35: Lisette's own dash, the Spirit Walk roll (strip frame 1/3)"
	],
	[
		"o1103_pin_dash_b",
		"archer",
		"spirit",
		0.6,
		2.0,
		"owner1103 #35: Lisette's own dash (strip frame 2/3)"
	],
	[
		"o1103_pin_dash_c",
		"archer",
		"spirit",
		0.7,
		2.0,
		"owner1103 #35: Lisette's own dash, out of the roll walking as a spirit (frame 3/3)"
	],
	[
		"o1103_bjorn_aegis_idle",
		"bulwark",
		"aegis",
		1.0,
		3.0,
		"owner1103 #29: the raised aegis, plated and bigger, the double chevron pulsing in front"
	],
	[
		"o1103_bjorn_aegis_push",
		"bulwark",
		"aegis_push",
		0.77,
		3.0,
		"owner1103 #29: a foe meets the aegis: the chevron flashes and the foe is pushed back"
	],
	[
		"o1103_bjorn_aegis_push_b",
		"bulwark",
		"aegis_push",
		1.05,
		3.0,
		"owner1103 #29: the foe has slid back 2 m off the aegis"
	],
	[
		"o1103_bjorn_aegis_break",
		"bulwark",
		"aegis_break",
		1.1,
		3.0,
		"owner1103 #29: the aegis breaking into chunks and dust"
	],
	[
		"o1103_bjorn_swing_a",
		"bulwark",
		"slam_dummy",
		1.78,
		2.5,
		"owner1103 #30: the held swing, strip 1/5, the wind-up"
	],
	[
		"o1103_bjorn_swing_b",
		"bulwark",
		"slam_dummy",
		1.86,
		2.5,
		"owner1103 #30: the held swing, strip 2/5, the hammer comes round, he steps in"
	],
	[
		"o1103_bjorn_swing_c",
		"bulwark",
		"slam_dummy",
		1.94,
		2.5,
		"owner1103 #30: the held swing, strip 3/5, the hit"
	],
	[
		"o1103_bjorn_swing_d",
		"bulwark",
		"slam_dummy",
		2.04,
		2.5,
		"owner1103 #30: the held swing, strip 4/5, the dummy knocked back, Breaker carried forward"
	],
	[
		"o1103_bjorn_swing_e",
		"bulwark",
		"slam_dummy",
		2.25,
		2.5,
		"owner1103 #30: the held swing, strip 5/5, the dummy 2 m or more away"
	],
	[
		"o1103_bjorn_dash_a",
		"bulwark",
		"smash",
		0.53,
		2.5,
		"owner1103 #35: Breaker's ground dash (360 Smash), strip 1/5, the push-off"
	],
	[
		"o1103_bjorn_dash_b",
		"bulwark",
		"smash",
		0.6,
		2.5,
		"owner1103 #35: Breaker's ground dash (360 Smash), strip 2/5, the stretched run-up behind the hammer"
	],
	[
		"o1103_bjorn_dash_c",
		"bulwark",
		"smash",
		0.72,
		2.5,
		"owner1103 #35: Breaker's ground dash (360 Smash), strip 3/5, the spin on arrival"
	],
	[
		"o1103_bjorn_dash_d",
		"bulwark",
		"smash",
		0.86,
		2.5,
		"owner1103 #35: Breaker's ground dash (360 Smash), strip 4/5, the low crouched recovery"
	],
	[
		"o1103_bjorn_dash_e",
		"bulwark",
		"smash",
		1.05,
		2.5,
		"owner1103 #35: Breaker's ground dash (360 Smash), strip 5/5, settled"
	],
	[
		"o1103_bjorn_air_dash_a",
		"bulwark",
		"lumber",
		0.52,
		2.5,
		"owner1103 #35: Breaker's air dash (the lumbering shove), strip 1/5, the shove off"
	],
	[
		"o1103_bjorn_air_dash_b",
		"bulwark",
		"lumber",
		0.58,
		2.5,
		"owner1103 #35: Breaker's air dash (the lumbering shove), strip 2/5, shoulder first"
	],
	[
		"o1103_bjorn_air_dash_c",
		"bulwark",
		"lumber",
		0.66,
		2.5,
		"owner1103 #35: Breaker's air dash (the lumbering shove), strip 3/5, the lumber through the air"
	],
	[
		"o1103_bjorn_air_dash_d",
		"bulwark",
		"lumber",
		0.76,
		2.5,
		"owner1103 #35: Breaker's air dash (the lumbering shove), strip 4/5, the end of the shove"
	],
	[
		"o1103_bjorn_air_dash_e",
		"bulwark",
		"lumber",
		0.9,
		2.5,
		"owner1103 #35: Breaker's air dash (the lumbering shove), strip 5/5, falling out of it"
	],
	[
		"o1103_bjorn_abyss",
		"bulwark",
		"bjorn_abyss",
		1.2,
		-6.0,
		"owner1103 #29: the Faultline's trail running on out over the abyss at his height"
	],
]
## The before/after pairs (top 3 gaps per hero), run on this build and, with --before, on an older one.
const PAIRS := [
	[
		"gap1_cursor_landing",
		"archer",
		"empowered_miss",
		0.95,
		3.0,
		"Gap 1 (aim): an Empowered arrow with the cursor at 5 m"
	],
	["gap2_draw_reticle", "archer", "draw", 0.45, 3.0, "Gap 2 (reticle): the bow mid-draw"],
	[
		"gap3_perfect",
		"archer",
		"perfect",
		0.68,
		2.5,
		"Gap 3 (perfect release): the frame after letting go on the stage"
	],
	["gap1_throw_cursor", "bulwark", "throw", 1.4, 3.0, "Gap 1 (aim): the hammer thrown with the cursor at 6 m"],
	["gap2_slam_numbers", "bulwark", "slam", 1.95, 2.5, "Gap 2 (numbers) and 4 (swing VFX): a full swing on the dummy"],
	["gap3_hold_glint", "bulwark", "spin", 1.25, 1.5, "Gap 3 (hold): the swing held 0.9 s"],
]

## The registry entry (--pin-bjorn-shots): needs --shots-dir=<dir>.
func run(main_node: Node) -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	if out == "":
		print("PINBJORN shots: pass --shots-dir=<dir>")
	else:
		await take(main_node, out)
	main_node.get_tree().quit(0)

func take(main_node: Node, out: String) -> void:
	main = main_node
	dir = out
	before = "--before" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(dir)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("archer"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0
	for x in m.hunters:
		if x != P and x != T: x.teleport(home + Vector3(-30, 0, 30))
	if m.hud: m.hud.visible = false
	var list: Array = PAIRS if before else SHOTS + PAIRS
	if "--owner1103" in OS.get_cmdline_user_args():
		list = OWNER
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			var want := String(a).substr(7).split(",")
			list = list.filter(func(e): return String(e[0]) in want)
	for s in list:
		await _shot(s, PAIRS.has(s))
	var f := FileAccess.open(dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	print("PINBJORN shots: %d in %s" % [lines.size(), dir])
	m.queue_free()
	await main.get_tree().process_frame

## Where a shot's close-up looks: an impact at the target, anything else between the hero and the lead.
func _close_focus(stem: String, lead: float) -> Vector3:
	if stem.ends_with("_hit") or stem.ends_with("_impact"):
		return T.pos
	return P.pos + Vector3(lead * 0.6, 0, 0)

func _spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(8, W.h - 8, 3):
		for x in range(10, W.w - 18, 3):
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-4, 5):
				for dx in range(-6, 13):
					var i: int = W.idx(x + dx, z + dz)
					if W.kind[i] != World.T_GROUND or int(
						W.level[i]
					) != lv or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false
						break
				if not good: break
			if good:
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	return start

## The nearest rock or tree tile to `p` that stands on open ground with free tiles west of it.
func _rock_near(p: Vector3) -> Vector3:
	var W = m.world
	var best := Vector3.INF
	for z in range(4, W.h - 4):
		for x in range(6, W.w - 4):
			if W.kind[W.idx(x, z)] != World.T_BLOCK: continue
			var ok := true
			for dx in range(1, 5):
				if W.kind[W.idx(x - dx, z)] != World.T_GROUND or W.kind[W.idx(x + 1, z)] == World.T_VOID: ok = false
			if not ok: continue
			var q := Vector3(x + 0.5, W.ground_at(x + 0.5, z + 0.5), z + 0.5)
			if best == Vector3.INF or q.distance_to(p) < best.distance_to(p): best = q
	return best

func _aim(at: Vector3) -> void:
	P.inp["aim"] = at + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = at.y

func _reset(hero: String) -> void:
	if P.arch != hero or P.wid != Arch.signature(hero):
		if m.arena: m.arena.set_arch(hero, Arch.signature(hero))
		else:
			P.reclass(Arch.weight(hero), hero, Arch.signature(hero))
			P.unlock_all()
		if m.arena and m.arena.card_layer: m.arena.card_layer.visible = false
	P.lvl = 6
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	P.inp["move"] = Vector2.ZERO
	T.teleport(home + Vector3(7.0, 0, 0))
	T.hp = T.max_hp
	T.vel = Vector3.ZERO
	T.stun_t = 0.0
	T.root_t = 0.0
	if m.arena:
		var i := 0
		for dm in m.arena.dummies:
			i += 1
			dm["at"] = home + Vector3(-14.0 - 3.0 * i, 0, -14.0)
			(dm["h"] as Hunter).teleport(dm["at"])
		if m.arena.get("bot") != null and is_instance_valid(m.arena.bot):
			(m.arena.bot as Hunter).teleport(home + Vector3(-20, 0, 14))
	var K = P.ak
	if K:
		K.cd["rmb"] = 0.0
		K.cd["e"] = 0.0
		K.ch_rmb = 2.0
		K.res = 0.0
		if K.get("draw") != null: K.get("draw").quick = false
		if K.get("mace") != null and not (K.get("mace") as Dictionary).is_empty() and K.has_method("_catch"):
			K.call("_catch", true)
	AimKit.clear(P)
	_aim(home + Vector3(7.0, 0, 0))

## The scripted input for one moment at time t (s since the shot started).
func _input(what: String, t: float) -> void:
	var K = P.ak
	var at := func(x: float) -> bool: return t >= x - DT * 0.5 and t < x + DT * 0.5
	match what:
		"aim":
			P.inp["fire"] = false
		"draw":
			P.inp["fire"] = t >= 0.0
			K.res = 0.0
		"draw_tgt":
			P.inp["fire"] = true
			K.res = 0.0
		"perfect":
			P.inp["fire"] = t < 0.62
			K.res = 0.0
		"quick":
			P.inp["fire"] = t < 0.62 or t > 0.76
			K.res = 0.0
		"empowered_miss":
			T.teleport(home + Vector3(0, 0, 8.0))
			_aim(home + Vector3(5.0, 0, 0))
			P.inp["fire"] = t >= 0.0 and t < 0.82
			K.res = 0.0
		"super_shot":
			_aim(home + Vector3(4.0, 0, 0))
			T.teleport(home + Vector3(10.0, 0, 0))
			P.inp["fire"] = t < 1.3
			K.res = 0.0
		"heavy":
			K.res = 0.0
			P.inp["sec_hold"] = t < 1.25
			if at.call(0.05): K.press_rmb()
		"spirit":
			P.inp["move"] = Vector2(1, 0) if t > 0.45 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
		"spirit_rock":
			if at.call(0.0):
				var rk := _rock_near(home)
				if rk != Vector3.INF:
					P.teleport(rk - Vector3(2.5, 0, 0))
					_aim(rk + Vector3(3, 0, 0))
			P.inp["move"] = Vector2(1, 0) if t > 0.45 and t < 0.8 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
			if at.call(0.85):
				var rk2 := _rock_near(home)
				if rk2 != Vector3.INF:
					P.teleport(rk2)
					P.vel = Vector3.ZERO
		"hail":
			K.res = 0.0
			_aim(home + Vector3(5.0, 0, 0))
			T.teleport(home + Vector3(5.0, 0, 0).rotated(Vector3.UP, 0.4))
			if at.call(0.5): K.use_e()
		"throw":
			T.teleport(home + Vector3(0, 0, 7.0))
			_aim(home + Vector3(6.0, 0, 0))
			P.inp["fire"] = at.call(0.5)
		"recall":
			T.teleport(home + Vector3(0, 0, 7.0))
			_aim(home + Vector3(5.0, 0, 0))
			P.inp["fire"] = at.call(0.5) or at.call(1.5)
		"spin":
			T.teleport(home + Vector3(2.4, 0, 0))
			_aim(T.pos)
			P.inp["fire"] = t > 0.4
		"slam":
			if t < 1.8: T.teleport(home + Vector3(2.4, 0, 0))
			_aim(home + Vector3(2.4, 0, 0))
			P.inp["fire"] = t > 0.4 and t < 1.82
		"aegis", "aegis_block", "aegis_break":
			T.teleport(home + Vector3(6.0, 0, 0))
			_aim(T.pos)
			P.inp["sec_hold"] = t > 0.45
			if at.call(0.5):
				K.set("lock_t", 0.0)
				K.press_rmb()
			if what != "aegis" and at.call(0.98):
				if what == "aegis_break" and K.get("wall") != null and not (K.get("wall") as Dictionary).is_empty():
					K.get("wall")["hp"] = 4.0
				m.spawn_shot(
					T,
					T.pos + Vector3(-0.6, 1.0, 0),
					Vector2(-40, 0),
					12.0,
					0.3,
					0.15,
					Color("ff6a4a"),
					{"kb": 0.0}
				)
		"heavy_pin":
			if t < DT:
				crush_rock = _rock_near(home)
				P.teleport(crush_rock - Vector3(8.0, 0, 0))
				T.teleport(crush_rock - Vector3(1.2, 0, 0))
			if t < 1.25:
				T.teleport(crush_rock - Vector3(1.2, 0, 0))
			_aim(crush_rock - Vector3(1.2, 0, 0))
			K.res = 0.0
			P.inp["sec_hold"] = t < 1.25
			if at.call(0.05): K.press_rmb()
		"aegis_push":
			if t < 0.69: T.teleport(home + Vector3(1.9, 0, 0))
			_aim(home + Vector3(6.0, 0, 0))
			P.inp["sec_hold"] = t > 0.45
			if at.call(0.5):
				K.set("lock_t", 0.0)
				K.press_rmb()
		"slam_dummy":
			if t < 1.8: T.teleport(home + Vector3(2.9, 0, 0))
			_aim(home + Vector3(2.9, 0, 0))
			P.inp["fire"] = t > 0.4 and t < 1.82
		"bjorn_abyss":
			T.teleport(home + Vector3(0, 0, 14.0))
			_aim(home + Vector3(-9.0, 0, 0))
			if at.call(0.3):
				K.cd["x"] = 0.0
				HunterKeys.ult_pressed(P)
		"smash":
			T.teleport(home + Vector3(5.6, 0, 0))
			_aim(T.pos)
			P.inp["move"] = Vector2(1, 0) if t > 0.45 and t < 0.7 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
		"lumber":
			_aim(home + Vector3(6.0, 0, 0))
			if at.call(0.4):
				P.pos += Vector3(0, 5.0, 0)
				P.grounded = false
			P.inp["move"] = Vector2(1, 0) if t > 0.45 and t < 0.7 else Vector2.ZERO
			if at.call(0.5): P.do_dash()
		"purify":
			P.hp = P.max_hp * 0.6
			if at.call(0.95): K.use_e()
		"pin_ult", "pin_ult_final":
			T.teleport(home + Vector3(7.0, 0, 0))
			_aim(T.pos)
			if at.call(0.3):
				K.cd["x"] = 0.0
				HunterKeys.ult_pressed(P)
				if what == "pin_ult_final":
					K.ult.left = 1
			P.inp["fire"] = t > 0.8 and t < 0.85
		"bjorn_ult":
			if t < 0.8:
				T.teleport(home + Vector3(7.0, 0, 0))
			_aim(home + Vector3(7.0, 0, 0))
			if at.call(0.3):
				K.cd["x"] = 0.0
				HunterKeys.ult_pressed(P)
		"crush":
			if t < DT:
				crush_rock = _rock_near(home)
				P.teleport(crush_rock - Vector3(3.9, 0, 0))
				P.hp = P.max_hp * 0.6
			if t < 1.7:
				T.teleport(crush_rock - Vector3(1.4, 0, 0))
			_aim(crush_rock - Vector3(1.4, 0, 0))
			P.inp["fire"] = t > 0.3 and t < 1.72

func _shot(s: Array, pair: bool) -> void:
	var stem := String(s[0])
	var hero := String(s[1])
	var what := String(s[2])
	var cap_t := float(s[3])
	var lead := float(s[4])
	var caption := String(s[5])
	_reset(hero)
	for i in 30:
		m.step(DT)
		await main.get_tree().process_frame
	_reset(hero)
	var t := 0.0
	while t < cap_t:
		_input(what, t)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		P.face = atan2(-(P.inp["aim"].x - P.pos.x), -(P.inp["aim"].z - P.pos.z))
		m.cam.snap(P.pos + Vector3(lead, 0, 0))
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	if "--shots-debug" in OS.get_cmdline_user_args():
		print(
			"SHOT %s dash=%s grounded=%s dashes=%.1f ex_cd=%.1f e_cd=%.1f in_e=%s anim=%s pos=%s" % [
				stem,
				str(P.ak.st.get("last_dash")),
				P.grounded,
				P.dashes,
				P.ex_cd,
				float(P.ak.cd["e"]),
				P.ak.in_e(),
				P.ak.anim_id,
				str(P.pos - home)
			]
		)
	if "--shots-debug" in OS.get_cmdline_user_args() and P.ak.get("fx") != null:
		var fxn: Node3D = P.ak.get("fx")
		var vis := []
		for c in fxn.get_children():
			if c is Node3D and (c as Node3D).visible:
				vis.append(
					"%s@%s tree=%s" % [
						c.name,
						str((c as Node3D).global_position - home),
						(c as Node3D).is_visible_in_tree()
					]
				)
		print("  FX in_tree=%s vis=%s visible_nodes=%s" % [fxn.is_inside_tree(), fxn.is_visible_in_tree(), str(vis)])
	if DisplayServer.get_name() == "headless":
		return
	var img := main.get_viewport().get_texture().get_image()
	var nm := "pin" if hero == "archer" else "bjorn"
	var prefix := ""
	var caption_prefix := ""
	if before:
		prefix = "before_"
		caption_prefix = "Before: "
	elif pair:
		prefix = "after_"
		caption_prefix = "After: "
	var file := prefix + stem + ".png"
	img.save_png(dir.path_join(file))
	lines.append("%s/v2/polish|%s|%s%s (gameplay zoom)" % [nm, file, caption_prefix, caption])
	# the same moment again from close up (the effects run on one more frame)
	m.cam.zoom = CLOSE_ZOOM
	m.cam.zoom_to = CLOSE_ZOOM
	m.cam.snap(_close_focus(stem, lead))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var close_file := prefix + stem + "_close.png"
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(close_file))
	lines.append("%s/v2/polish|%s|%s%s (close-up)" % [nm, close_file, caption_prefix, caption])
	m.cam.zoom = 1.0
	m.cam.zoom_to = 1.0
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	P.inp["move"] = Vector2.ZERO
	for i in 40:
		m.step(DT)
	AimKit.clear(P)
