extends RefCounted
## --ways-out-map-check: where the Ways Out seats sit on each expedition map (briefs/specs/LIMITED_WAY_OUTS.md
## section 8; numbers in content/rules/heart.json "map", stretched by the map's "ways_scale"). For each map,
## two seeds of a real match:
##   1. the map authors "heart" and the match's Heart stands on it; the ways_scale matches the map's size
##   2. the seeded Gate is gate_dist from the Heart on its island, inside the final ring, gate_clear from
##      both uplinks, and another seed puts it elsewhere
##   3. exactly two uplink outposts, both in the band and uplink_apart_deg round the Heart
##   4. every quest site (lairs, outposts) is inside the tide ring seat_window_s after it opens and
##      outside the final ring
## Never touches the save.

const MAPS := {"hollowcrown": 305.0 / 216.0, "skyreach": 1.0}  # map -> ways_scale (its size over the 216 m design)
const SEEDS := [5101, 5102]

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("WAYSMAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for id in MAPS:
		var L := World.load_layout(id)
		ok(L.has("heart"), "%s authors a heart site" % id)
		var ws := float(L.get("ways_scale", 1.0))
		ok(absf(ws - MAPS[id]) < 0.01, "%s ways_scale %.3f" % [id, ws])
		var gates: Array = []
		for sd in SEEDS:
			var m := Match.new()
			main.add_child(m)
			m.start(
				{
					"teams": 2,
					"squad": 1,
					"tier": 0,
					"length": 1e9,
					"seed": sd,
					"no_drop": true,
					"heart": true,
					"map": id
				}
			)
			m.set_process(false)
			_map(m, L, id)
			if m.heart:
				gates.append(m.heart.gate)
			m.queue_free()
			await main.get_tree().process_frame
		ok(gates.size() == 2 and gates[0] != gates[1], "%s: another seed seeds another Gate" % id)
	print("ways-out-map-check: %d failures" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _map(m: Match, L: Dictionary, id: String) -> void:
	var H := m.heart
	var w := m.world
	var mr: Dictionary = Heart.rules()["map"]
	var tag := "%s seed %d" % [id, m.seed_val]
	ok(H != null and w.layout_id == id, "%s: a real match on the map has a Heart" % tag)
	if H == null:
		return
	var s := H.ways_scale
	var final_r := Heart.r("tide_r1") * s
	var site := Vector2(H.site.x, H.site.z)
	var hs := _tile(L["heart"])
	ok(
		site.distance_to(hs) < 2.0 and not w.is_void(site.x, site.y),
		"%s: the Heart stands on its site %s" % [tag, L["heart"]]
	)
	# the Gate
	var gate := Vector2(H.gate.x, H.gate.z)
	var gd := gate.distance_to(site)
	var want := Heart.r("gate_dist") * s
	var on_isle := not w.is_void(gate.x, gate.y) and w.island_of(gate.x, gate.y) == w.island_of(site.x, site.y)
	ok(
		absf(gd - want) < 3.5 and gd < final_r and on_isle,
		"%s: the Gate is %.1f m from the Heart on its island (want %.1f, final ring %.1f)" % [tag, gd, want, final_r]
	)
	var ups: Array = w.exit_defs.filter(func(ed): return ed["kind"] == "outpost")
	ok(ups.size() == 2, "%s: %d uplink outposts (want 2)" % [tag, ups.size()])
	var lo := float(mr["uplink_band"][0]) * s
	var hi := float(mr["uplink_band"][1]) * s
	var clear := float(mr["gate_clear"]) * s
	var angs: Array = []
	for ed in ups:
		var p := Vector2(ed["pos"].x, ed["pos"].z)
		var d := p.distance_to(site)
		ok(
			d >= lo - 1.0 and d <= hi + 1.0,
			"%s: uplink %s is %.1f m from the Heart (band %.0f-%.0f)" % [tag, ed["at"], d, lo, hi]
		)
		var dg := p.distance_to(gate)
		ok(dg >= clear, "%s: uplink %s is %.1f m from the Gate (want %.0f)" % [tag, ed["at"], dg, clear])
		angs.append((p - site).angle())
	if angs.size() == 2:
		var apart := rad_to_deg(absf(angle_difference(angs[0], angs[1])))
		ok(
			apart >= float(mr["uplink_apart_deg"]),
			"%s: the uplinks are %.0f degrees apart round the Heart" % [tag, apart]
		)
	# the tide rule: open + seat_window_s still inside the ring, never inside the final ring
	var q: Dictionary = Heart.rules()["quest"]
	var sites: Array = []
	for LD in L.get("lairs", []):
		sites.append(["lair " + String(LD["id"]), _tile(LD["at"]), float(q["lair_open_s"])])
	for ed in ups:
		sites.append(["uplink %s" % [ed["at"]], Vector2(ed["pos"].x, ed["pos"].z), float(q["uplink_open_s"])])
	for st in sites:
		var d: float = (st[1] as Vector2).distance_to(site)
		var t: float = st[2] + float(mr["seat_window_s"])
		var ring := minf(Heart.start_r_of(L, {"squad": 1}), Heart.ring_at(t, s))  # (solos: the smallest play space)
		ok(
			d <= ring and d > final_r,
			"%s: %s is %.1f m out, ring %.1f m at %.0f s, final ring %.1f m" % [tag, st[0], d, ring, t, final_r]
		)


## The centre of an authored tile [x, z].
func _tile(a: Array) -> Vector2:
	return Vector2(float(a[0]) + 0.5, float(a[1]) + 0.5)
