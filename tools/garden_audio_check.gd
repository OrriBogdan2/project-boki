extends RefCounted
## --garden-audio-check (briefs/design/GARDEN.md 10.2, docs/AUDIO.md): each zone and the hub has its own
## ambience bed under the time-of-day bed, Hushwood's clock stays at dusk, a hop plays its sound (as long
## as the Waystone's light-up) and a zone waking plays its sting once. Part 1 runs HomeAmbience on its own
## for every zone; part 2 travels hub -> Bramblebank through the real Waystone and reads each home's beds.

const WAIT_S := 30.0      # s to wait for a home to finish building before failing
const TICK_S := 0.25      # s per simulated ambience step
const SETTLE_S := 6.0     # s of steps for a zone's bed to come up (ZONE_FADE_S is 3)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GARDENAUDIO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	_bed_part()
	_cue_part()
	await _travel_part(m)
	print("GARDENAUDIO %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)

func _zones() -> Array:
	return GardenZones.ids() + [GardenZones.HUB]

## Every zone and the hub: a distinct bed that comes up beside one time-of-day bed, within the loop budget.
func _bed_part() -> void:
	var seen := {}
	for z: String in _zones():
		var bed := HomeAmbience.zone_bed(z)
		seen[bed] = true
		GardenZones.here = z
		var h := HomeAmbience.new()
		var peak := 0
		for i in int(SETTLE_S / TICK_S):
			h.tick(TICK_S, 0.5, false, {}, Vector3.ZERO)
			Sfx._process(TICK_S)
			peak = maxi(peak, Sfx.amb_layers.size())
		var timed := Sfx.amb_layers.keys().filter(func(n): return n.begins_with("garden_"))
		ok(ResourceLoader.exists("res://audio/amb_%s.ogg" % bed) and float(h.levels.get(bed, 0.0)) >= 0.99
			and Sfx.amb_layers.has(bed) and timed.size() == 1 and peak <= HomeAmbience.MAX_LOOPS,
			"%s: %s plays under %s (%d loops at most)" % [z, bed, timed, peak])
		Sfx.clear_amb_layers(0.0)
	ok(seen.size() == _zones().size(), "every zone and the hub have their own bed (%d)" % seen.size())
	var dusk := HomeAmbience.bed_for(HomeAmbience.clock_in("hushwood", 0.3), false)
	var morning := HomeAmbience.bed_for(HomeAmbience.clock_in("bramblebank", 0.3), false)
	ok(dusk == "garden_evening" and morning == "garden_morning",
		"Hushwood stays at dusk, Bramblebank keeps the clock")
	GardenZones.here = ""

## The hop and the wake sounds exist, the hop is as long as the light-up, and waking a zone plays once.
func _cue_part() -> void:
	ok(Sfx.ensure("garden_hop") and Sfx.ensure("garden_wake"), "the hop and wake sounds exist")
	var len_s := (load("res://audio/garden_hop.wav") as AudioStream).get_length()
	var fade := float(GardenZones.rules()["hop_fade_s"])
	ok(len_s >= fade - 0.05 and len_s <= fade + 0.3,
		"the hop sound lasts %.2f s for the %.1f s light-up" % [len_s, fade])
	Save.d = Save.fresh()
	Sfx.last_played.erase("garden_wake")
	GardenZones.wake("glasswater")
	var at := int(Sfx.last_played.get("garden_wake", -1))
	ok(GardenZones.is_open("glasswater") and at >= 0, "waking Glasswater opens it with its sting")
	GardenZones.wake("glasswater")
	ok(int(Sfx.last_played["garden_wake"]) == at, "a zone that is already awake gives no second sting")

func _travel_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	var d := Save.fresh()
	d["roster"].append(Save.new_kin("zapple", "Pip"))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await _arrived(m, null)
	ok(hub != null and hub.ambience.levels.has(HomeAmbience.zone_bed(GardenZones.HUB)), "the hub plays its own bed")
	if hub == null:
		return
	Sfx.last_played.erase("garden_hop")
	ok(hub.hway.hop("bramblebank") and Sfx.last_played.has("garden_hop"), "the Waystone hop plays its sound")
	var bb = await _arrived(m, hub)
	var bed := HomeAmbience.zone_bed("bramblebank")
	var hub_bed := HomeAmbience.zone_bed(GardenZones.HUB)
	ok(bb != null and bb.ambience.levels.has(bed) and not bb.ambience.levels.has(hub_bed),
		"after the hop Bramblebank plays %s, the hub bed is gone" % bed)
	Content.rules("farm_build")["base_mode"] = false

## Waits for the home a goto started to be built and revealed, with a few ambience steps; null on a timeout.
func _arrived(m: Node, was: Node):
	var t := 0.0
	while t < WAIT_S:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
		var cur = Game.main.current
		if cur != was and is_instance_valid(cur) and cur.get("hway") != null and cur.get("player") != null \
				and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered \
				and not cur.ambience.levels.is_empty():
			return cur
	return null
