extends RefCounted
## The farm-side shots of the pitch reel (tools/pitch_reel.gd runs them under the 60 fps movie writer): the egg hatch,
## an evolution, the farm loop (feed, care, train) and the Hunter select scroll. All play the real screens on the demo
## save (Demo.save), driven by the same calls the buttons make.

const HATCH_KNOCK_S := 0.55      # s between the scripted knocks on the egg
const REVEAL_HOLD_S := 2.0       # s the Boki reveal is held once it has settled
const REVEAL_SETTLE_S := 3.5     # s the reveal takes to play in before the hold starts
const EVO_HOLD_S := 2.5          # s kept after the evolution scene ends
const SELECT_STEP_S := 0.85      # s each Hunter stays on screen while the select scrolls through them
const SELECT_LAND_S := 3.0       # s the chosen Hunter is held
const LOOP_PET_AT := 9.0         # s into the farm loop: pat a Boki
const LOOP_FETCH_AT := 14.0      # s: toss the ball for another
const LOOP_BRUSH_AT := 21.0      # s: brush a third
const LOOP_DRILL_AT := 28.0      # s: a fourth trains on the dummy
const GOLD_BAND := 0.03          # bar widths either side of the gold's centre the scripted press waits for

var rig                  # the PitchReel running the shot (main, wait(), mark(), FPS)
var home: Node

func _init(r) -> void:
	rig = r

## The farm on the demo save, built and shown, with the home screen in `home`.
func _farm(preset: String, set_up := true) -> void:
	if set_up:
		Demo.setup(preset)
	await rig.main.show_screen("home", {})
	home = rig.main.current
	while home.building or not is_instance_valid(home.root_ui):
		await rig.main.get_tree().process_frame
	await rig.main.fade.reveal(0.01)
	await rig.wait(1.0)

## Shot 2: the egg is picked, knocked on until it cracks, and the Boki is revealed and held (a fresh save, the real
## hatch screen).
func hatch(take: int) -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	await rig.main.show_screen("hatch", {})
	var hx = rig.main.current
	for _i in 3:
		await rig.main.get_tree().process_frame
	await rig.main.fade.reveal(0.01)
	hx._end_intro()
	await rig.wait(2.0)
	hx._pick(take % hx.eggs.size())
	await rig.wait(0.8)
	hx._pick(take % hx.eggs.size())
	rig.mark("hatch")
	while hx.stage != "reveal":
		await rig.wait(HATCH_KNOCK_S)
		hx._tap_egg()
	rig.mark("reveal")
	await rig.wait(REVEAL_SETTLE_S + REVEAL_HOLD_S)

## Shot 3: a Boki that is one level from its next form takes it: the farm's own evolution scene.
func evolve() -> void:
	Demo.setup("farm")
	var rec := _about_to_evolve()
	await _farm("farm", false)
	if rec.is_empty():
		rig.fail("no Boki species has a level evolution whose form has art yet (waits for the new models)")
		return
	rig.mark("evolve")
	Evo.level_up(rec)
	Game._evolve(rec, {})
	home._play_evolutions()
	await rig.wait(1.0)
	while home.building_now:
		await rig.wait(0.25)
	await rig.wait(EVO_HOLD_S)

## The first roster Boki whose level line has an evolution with art, put one level short of it. When the demo farm
## holds none, its first Boki becomes the first species whose line has art (at both ends if any line has; picked
## before the farm is built, so the farm shows that species).
func _about_to_evolve() -> Dictionary:
	var roster: Array = Save.d["roster"]
	for rec in roster:
		if _evolves_with_art(String(rec["species"]), false):
			return _one_short(rec)
	for both_ends in [true, false]:      # (until the T1 models land, only the T2 form may have art)
		for sp in Evo.rules()["lines"]:
			if not roster.is_empty() and _evolves_with_art(String(sp), both_ends):
				roster[0]["species"] = String(sp)
				return _one_short(roster[0])
	return {}

func _evolves_with_art(sp: String, both_ends: bool) -> bool:
	var line: Dictionary = Evo.rules()["lines"].get(sp, {})
	if not Data.KIN.has(sp) or not line.has("level") or line.get("into", []).is_empty():
		return false
	return Evo.has_art(String(line["into"][0]["id"])) and (not both_ends or Evo.has_art(sp))

func _one_short(rec: Dictionary) -> Dictionary:
	rec["level"] = int(Evo.rules()["lines"][String(rec["species"])]["level"]) - 1
	return rec

## Shot 4: hungry Boki walk to the trough and eat, then one is patted, one plays fetch, one is brushed and one trains
## on the dummy (three rounds, pressed in the gold). The camera stays where the farm puts it.
func farm_loop(secs: float) -> void:
	await _farm("care")
	var kins: Array = home.kins.filter(func(k): return not k.has("indoors"))
	rig.mark("farm")
	var t := 0.0
	var step: float = 1.0 / rig.FPS
	var did := {}
	while t < secs:
		await rig.main.get_tree().process_frame
		t += step
		_loop_beat(t, kins, did)
		_press_in_gold()

func _loop_beat(t: float, kins: Array, did: Dictionary) -> void:
	for beat in [[LOOP_PET_AT, 0], [LOOP_FETCH_AT, 1], [LOOP_BRUSH_AT, 2], [LOOP_DRILL_AT, 3]]:
		if t < beat[0] or did.has(beat[1]) or beat[1] >= kins.size():
			continue
		did[beat[1]] = true
		var k: Dictionary = kins[beat[1]]
		match beat[1]:
			0: home._pet_kin(k)
			1: home._play_with_kin(k)
			2: home._care_brush(k["rec"])
			3: home._start_drill(k["rec"], "power")

## The drill's marker is pressed as it crosses the gold.
func _press_in_gold() -> void:
	if home.train.is_empty() or float(home.train["wait"]) > 0.0:
		return
	var bar: TimingBar = home.train["bar"]
	if absf(bar.m - bar.zone) < GOLD_BAND:
		home._train_hit()

## Shot 6: the Hunters screen (J on the farm) steps through every Hunter, then lands on `chosen` and picks it.
func hunter_select(chosen: String) -> void:
	await _farm("farm")
	HomeClasses.open(home, "")
	await rig.wait(1.0)
	rig.mark("select")
	for id in HomeClasses.ordered():
		HomeClasses._show(home, String(id))
		await rig.wait(SELECT_STEP_S)
	HomeClasses._show(home, chosen)
	await rig.wait(SELECT_LAND_S)
	# the pick is saved with the screen still up (HomeHero.pick closes it, and the take would end on the farm)
	HeroGrid.save_pick(chosen)
	HomeClasses._show(home, chosen)
	await rig.wait(1.0)
