extends RefCounted
## --boki-rig-check, the fliers on the farm (BokiFly, content/rules/boki_fly.json). Two fliers and a walker live
## SIM_SECS on Kitewind Ridge (home.gd _move_kin at 30 steps a second, BaseLife at 10 Hz, each flier's rig picking
## its clip every step): a roaming flier never walks the ground more than GROUND_MAX in a row, hovers 0.5 to 1.5 m
## up, and flares each time it lands (one is petted mid-hover to make sure); the walker never leaves the ground. Then
## the gaps: a flier on a bridge over the void and one leaping to another isle glide it and flare at the end. Never
## touches the real save.

const SIM_SECS := 120.0
const DT := 1.0 / 30.0
const GROUND_MAX := 3.0        # s: the longest a roaming flier may walk the ground in a row on Kitewind Ridge
const SETTLED := 1.0           # s up and still before a hover's height counts (it climbs first)
const PET_HOLD := 3.0          # s the farm holds a petted Boki
const PET_WATCH := 2.0         # s watched after the pet: down from 1.5 m at sink, plus the flare, takes under it
const FLIERS := ["kestrike", "wisplet"]
const WALKER := "cindle"

var check                      # the --boki-rig-check run: ok() prints and counts each row
var main: Node
var home

func run(m: Node, c) -> void:
	main = m
	check = c
	Save.no_write = true
	seed(7)
	var farm_rules: Dictionary = Content.rules("farm_build")
	farm_rules["base_mode"] = true
	_new_save()
	home = await _ridge_home()
	check.ok(GardenZones.here == "ridge" and home.life != null, "fliers: the farm opens on Kitewind Ridge, BaseLife on")
	home.day_t = 0.4
	home.ppos = Vector3(-500, 0, -500)       # you are away: nobody comes to sit by you
	_roam()
	_bridge()
	_leap()
	farm_rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

func _new_save() -> void:
	var d := Save.fresh()
	for sp in FLIERS + [WALKER]:
		var rec := Save.new_kin(sp, String(sp).capitalize())
		rec["zone"] = "ridge"
		(d["roster"] as Array).append(rec)
	d["active"] = d["roster"][FLIERS.size()]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}      # no base tutorial (Lead)
	d["zones"]["ridge"] = {"open": true}
	Save.d = d
	HomeLayout.ensure(d)

func _ridge_home():
	var hm = load("res://scripts/home/home.gd").new()
	hm.zone = "ridge"
	main.add_child(hm)
	main.current = hm
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building:
		await main.get_tree().process_frame
	return hm

func _kin(species: String) -> Dictionary:
	for k in home.kins:
		if String(k["rec"]["species"]) == species:
			return k
	return {}

func _rig(k: Dictionary) -> BokiRig:
	return (k["node"] as Node3D).find_child("BokiRig", true, false) as BokiRig

## Steps the farm once and every flier's rig; returns how many landings flared and how many there were.
func _step(fliers: Array) -> Vector2i:
	home._move_kin(DT)
	var out := Vector2i.ZERO
	for k in fliers:
		var rig := _rig(k)
		var was := rig._aloft
		rig._track_speed(DT)
		rig._pick_clip(DT)
		if was and not rig._aloft:
			out += Vector2i(1 if rig.clip == "flare" else 0, 1)
	return out

func _roam() -> void:
	var fliers: Array = FLIERS.map(func(sp: String) -> Dictionary: return _kin(sp))
	var walker := _kin(WALKER)
	check.ok(fliers.all(func(k: Dictionary) -> bool: return not k.is_empty()) and not walker.is_empty(),
		"fliers: %s and the walker %s are out" % [", ".join(FLIERS), WALKER])
	var on_foot := {}              # flier uid -> s it has walked the ground in a row while roaming
	var longest := 0.0
	var roam_s := 0.0
	var air_s := 0.0
	var hover := Vector2(INF, -INF)
	var still_up := {}
	var flares := Vector2i.ZERO
	var walker_up := false
	var petted := false
	var t := 0.0
	while t < SIM_SECS:
		flares += _step(fliers)
		t += DT
		walker_up = walker_up or walker.has("fly") or bool(walker["node"].get_meta("aloft", false))
		for k in fliers:
			var uid := String(k["rec"]["uid"])
			if not BaseLife.roams(k):
				on_foot[uid] = 0.0
				still_up[uid] = 0.0
				continue
			var up: bool = k.has("fly")
			var speed := Vector2(k["vel"].x, k["vel"].z).length()
			roam_s += DT
			air_s += DT if up else 0.0
			on_foot[uid] = float(on_foot.get(uid, 0.0)) + DT if not up and speed >= BokiRig.WALK_SPEED else 0.0
			longest = maxf(longest, float(on_foot[uid]))
			still_up[uid] = float(still_up.get(uid, 0.0)) + DT if up and speed < BokiRig.WALK_SPEED else 0.0
			if float(still_up[uid]) >= SETTLED:
				var lift := float(k["fly"]["h"])
				hover = Vector2(minf(hover.x, lift), maxf(hover.y, lift))
				if not petted:
					petted = true
					flares += _taken_lands(k, fliers)
	var band: Array = BokiFly.rules()["height"]
	check.ok(roam_s >= SIM_SECS * 0.25 and air_s >= roam_s * 0.9,
		"fliers: roaming on Kitewind Ridge they are up (%.0f of %.0f s)" % [air_s, roam_s])
	check.ok(longest <= GROUND_MAX,
		"fliers: a roaming flier never walks the ground over %.0f s in a row (longest %.2f s)" % [GROUND_MAX, longest])
	check.ok(hover.x <= hover.y and hover.x >= float(band[0]) - 0.01 and hover.y <= float(band[1]) + 0.01,
		"fliers: hovering they hold %.1f to %.1f m up (%.2f to %.2f)" % [band[0], band[1], hover.x, hover.y])
	check.ok(not walker_up, "fliers: the walker %s never leaves the ground" % WALKER)
	check.ok(flares.y >= 1 and flares.x == flares.y, "fliers: every landing flares before it walks (%d of %d)"
		% [flares.x, flares.y])
	if not petted:
		check.ok(false, "fliers: one hovered long enough to be petted")

## Petted (the farm's hold) while it hovers, a flier is no longer roaming: it comes down with a flare and stands.
## Returns the landings seen meanwhile, as _step does.
func _taken_lands(k: Dictionary, fliers: Array) -> Vector2i:
	var n: Node3D = k["node"]
	var clips := {}
	var flares := Vector2i.ZERO
	k["hold_t"] = PET_HOLD
	var t := 0.0
	while t < PET_WATCH:
		flares += _step(fliers)
		t += DT
		clips[_rig(k).clip] = true
	var grounded := not k.has("fly") and is_zero_approx(float(n.get_meta("lift", 0.0)))
	var ends_on := _rig(k).clip
	check.ok(clips.has("flare") and grounded and ends_on != "hover" and ends_on != "glide" and ends_on != "flare",
		"fliers: petted while it hovers it comes down, flares and stands (%s)" % ", ".join(clips.keys()))
	k["hold_t"] = 0.0
	return flares

## A flier that walks onto a bridge over the void takes off over it and lands past it; a walker stays on the planks.
func _bridge() -> void:
	var k := _kin(FLIERS[1])
	var w: World = home.world
	var pos: Vector3 = k["pos"]
	var tile := w.idx(floori(pos.x), floori(pos.z))
	w.bridge[tile] = true
	k["hold_t"] = 5.0              # held by the farm: not roaming, only the gap lifts it
	home.fly.land(k)
	var n: Node3D = k["node"]
	var up := 0.0
	for i in 30:
		n.position = k["pos"]
		home.fly.step(k, k["pos"], n, DT)
		up = maxf(up, float(n.get_meta("lift", 0.0)))
	check.ok(up > 0.3 and bool(n.get_meta("aloft", false)), "fliers: on a bridge over the void it glides (%.2f m up)"
		% up)
	w.bridge.erase(tile)
	var rig := _rig(k)
	var flared := false
	for i in 60:
		n.position = k["pos"]
		home.fly.step(k, k["pos"], n, DT)
		rig._pick_clip(DT)
		flared = flared or rig.clip == "flare"
	check.ok(flared and not k.has("fly"), "fliers: past the gap it lands with a flare")
	var walker := _kin(WALKER)
	var planks := w.idx(floori(walker["pos"].x), floori(walker["pos"].z))
	w.bridge[planks] = true
	var wn: Node3D = walker["node"]
	check.ok(not home.fly.step(walker, walker["pos"], wn, DT), "fliers: the walker crosses the planks on foot")
	w.bridge.erase(planks)
	k["hold_t"] = 0.0

## A flier called to another isle leaps the gap gliding and flares as it comes down; the leap keeps its own timing.
func _leap() -> void:
	var k := _kin(FLIERS[0])
	var rig := _rig(k)
	var to: Vector3 = k["pos"] + Vector3(8.0, 0.0, 0.0)
	home._start_leap(k, to)
	var dur := float(k["leap"]["dur"])
	var seen := {}
	var t := 0.0
	while k.has("leap") and t < 5.0:
		_step([k])
		t += DT
		seen[rig.clip] = true
	check.ok(seen.has("glide") and seen.has("flare") and not seen.has("run"),
		"fliers: the leap to another isle glides and flares (%s)" % ", ".join(seen.keys()))
	check.ok(absf(t - dur) <= DT * 1.5, "fliers: the leap still takes its %.2f s (%.2f)" % [dur, t])
