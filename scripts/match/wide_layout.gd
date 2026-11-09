class_name WideLayout
extends RefCounted
## The wide map for rolling sessions (docs/ROADMAP.md section 0.6), moved out of world.gd.
## The ring links are written for Skyreach's island ids, so only Skyreach is widened; any other
## authored map is used as it is (the Hollow Crown is hand-built in world coordinates).

const MAP := "skyreach"        # the authored map the wide layout is made from

## The layout a match loads. Rolling sessions use the wide Skyreach unless a map was asked for with
## opts.map / --map= (that one is used as it is). opts.narrow keeps plain Skyreach.
static func pick(o: Dictionary, rolling: bool, tier: int) -> Dictionary:
	var explicit := o.has("map") or Array(OS.get_cmdline_user_args()).any(func(x): return String(x).begins_with("--map="))
	if not rolling or explicit:
		return World.load_layout(String(o.get("map", World.layout_for_tier(tier))))
	var L := World.load_layout(MAP)
	return L if o.get("narrow", false) or L.is_empty() else widen(L)

## A 30-minute rolling session keeps 24-40 hunters on the map, so it needs more room than a 20-hunter
## match: the layout is moved in by WIDE_PAD tiles on every side and a ring of eight calm outer islands
## goes round it (danger 0, so waves can come down somewhere quiet), each joined by a land bridge to the
## corner island beside it and by a wind road to the landing on its other side. Everything else
## (regions, lairs, exits, the train) is the hand-made Skyreach, unchanged.
const WIDE_PAD := 36
const WIDE_R := 118.0          # how far out the ring islands sit from the middle
const WIDE_ISLE_R := 16.0
## [angle (deg, 0 = east, clockwise on the map), id, name, role, the corner island it bridges to, the landing it has a wind road to]
const WIDE_RING := [
	[22.5, "o_salt", "Saltwind Shelf", "grove", "still", "fern"],
	[67.5, "o_drift", "Driftmoor", "camp", "still", "dawn"],
	[112.5, "o_kestrel", "Kestrel Rise", "nest", "moss", "dawn"],
	[157.5, "o_hollow", "Hollowmere", "camp", "moss", "iron"],
	[202.5, "o_cinder", "Cinderfall Ledge", "grove", "lantern", "iron"],
	[247.5, "o_ashen", "Ashen Terrace", "camp", "lantern", "skyport"],
	[292.5, "o_rime", "Rimefold", "nest", "gull", "skyport"],
	[337.5, "o_bright", "Brightwater Shoal", "camp", "gull", "fern"],
]

## The rolling-session version of an authored layout (see WIDE_RING). Pure data: the same layout
## always gives the same wide one.
static func widen(L: Dictionary) -> Dictionary:
	var W: Dictionary = L.duplicate(true)
	var p := float(WIDE_PAD)
	var sh2 := func(a) -> Array:
		var o: Array = (a as Array).duplicate()
		o[0] = float(o[0]) + p; o[1] = float(o[1]) + p
		return o
	var sh4 := func(a) -> Array:
		var o: Array = (a as Array).duplicate()
		for i in 4: o[i] = float(o[i]) + p
		return o
	W["id"] = String(L.get("id", "authored")) + "_wide"
	W["name"] = String(L.get("name", ""))
	var size := int(L.get("size", World.BIG_SIZE))
	W["size"] = size + WIDE_PAD * 2
	for I in W.get("islands", []):
		if I.has("poi"): I["poi"] = sh2.call(I["poi"])
		if I.has("weapon"): I["weapon"] = sh2.call(I["weapon"])
		for S in I.get("shapes", []):
			for k in ["circle", "ellipse"]:
				if S.has(k): S[k] = sh2.call(S[k])
			for k in ["capsule", "rect"]:
				if S.has(k): S[k] = sh4.call(S[k])
		for k in ["bush", "chests", "pillars", "extras"]:
			if I.has(k): I[k] = (I[k] as Array).map(func(a): return sh2.call(a))
		for Wd in I.get("walls", []):
			if Wd.has("ring"): Wd["ring"] = sh2.call(Wd["ring"])
			for k in ["box", "line"]:
				if Wd.has(k): Wd[k] = sh4.call(Wd[k])
	for B in W.get("bridges", []):
		B["from"] = sh2.call(B["from"]); B["to"] = sh2.call(B["to"])
	for U in W.get("updrafts", []):
		U["at"] = sh2.call(U["at"])
	if W.has("train"): W["train"]["center"] = sh2.call(W["train"]["center"])
	for k in ["docks", "outposts", "hatches", "portals"]:
		if W.has(k): W[k] = (W[k] as Array).map(func(a): return sh2.call(a))
	for LD in W.get("lairs", []):
		LD["at"] = sh2.call(LD["at"])
	for cat in W.get("spawn_points", {}):
		var sp: Dictionary = W["spawn_points"][cat]
		sp["points"] = (sp.get("points", []) as Array).map(func(a): return sh2.call(a))
	# the ring
	var by_id := {}
	for I in W.get("islands", []):
		by_id[String(I["id"])] = I
	var c := Vector2(W["size"] / 2.0, W["size"] / 2.0)
	for R in WIDE_RING:
		var ang := deg_to_rad(float(R[0]))
		var cen := c + Vector2(cos(ang), sin(ang)) * WIDE_R
		var corner: Dictionary = by_id.get(String(R[4]), {})
		var inner := cen - Vector2(cos(ang), sin(ang)) * 5.0 + Vector2(-sin(ang), cos(ang)) * 3.0
		var isl := {"id": String(R[1]), "name": String(R[2]), "role": String(R[3]), "region": int(corner.get("region", 0)), "danger": 0,
			"poi": [snappedf(cen.x, 0.5), snappedf(cen.y, 0.5)], "noise": 0.14, "biome": String(corner.get("biome", "meadow")),
			"shapes": [{"circle": [cen.x, cen.y], "r": WIDE_ISLE_R, "lv": 0}, {"circle": [inner.x, inner.y], "r": 7.5, "lv": 1}],
			# the side facing out over the clouds is a sheer drop; the rest has a lip you can catch
			"sheer": [[fposmod(float(R[0]) - 50.0, 360.0), fposmod(float(R[0]) + 50.0, 360.0)]],
			"bush": [[cen.x + cos(ang + 2.0) * 9.0, cen.y + sin(ang + 2.0) * 9.0, 1.6], [cen.x + cos(ang - 2.0) * 9.0, cen.y + sin(ang - 2.0) * 9.0, 1.4]]}
		W["islands"].append(isl)
		by_id[isl["id"]] = isl
		if not corner.is_empty():
			var cc: Array = (corner["shapes"][0] as Dictionary).get("circle", corner["poi"])
			var cv := Vector2(float(cc[0]), float(cc[1]))
			var cr := float((corner["shapes"][0] as Dictionary).get("r", 15.0))
			var dirn := (cv - cen).normalized()
			var f := cen + dirn * (WIDE_ISLE_R - 2.5); var t := cv - dirn * (cr - 2.5)
			W["bridges"].append({"name": String(R[2]).get_slice(" ", 0) + " Span", "a": String(R[1]), "b": String(R[4]), "from": [f.x, f.y], "to": [t.x, t.y], "r": 1.8})
		if by_id.has(String(R[5])):
			W["winds"].append([String(R[1]), String(R[5])])
		# loot and rare Boki spots out on the ring too, so a wave landing there has something close
		var away := cen + Vector2(cos(ang + 1.2), sin(ang + 1.2)) * 7.0
		W["spawn_points"]["cache"]["points"].append([int(away.x), int(away.y), String(R[2])])
		if String(R[3]) == "nest" or String(R[3]) == "grove":
			var rk := cen + Vector2(cos(ang - 1.3), sin(ang - 1.3)) * 8.0
			W["spawn_points"]["rare_kin"]["points"].append([int(rk.x), int(rk.y), String(R[2])])
	if W["spawn_points"].has("cache"): W["spawn_points"]["cache"]["pick"] = [7, 7]
	if W["spawn_points"].has("rare_kin"): W["spawn_points"]["rare_kin"]["pick"] = [4, 4]
	return W
