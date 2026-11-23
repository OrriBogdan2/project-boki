extends RefCounted
## The combat-clarity fight (docs/COMBAT_CLARITY.md "What sits on a Hunter"): a bot trio-vs-trio on the Hollow Crown
## with the slice Hunters, and the count of what sits over or within one body width of each Hunter (words, numbers,
## icons, rings and effects; the Hunters' and Boki's own bodies are not counted). --clarity-shots films it (10 frames
## at 1920x1080 per fight), --clarity-check holds it to BUDGET.

const DT := 1.0 / 60.0
const MAP := "hollowcrown"
const FIGHTS := [  # the slice Hunters (Vex, Kael, Lace, Cinder), yours first
	["gunslinger", "juggernaut", "archer", "ashwick", "gunslinger", "juggernaut"],
	["ashwick", "archer", "gunslinger", "archer", "ashwick", "juggernaut"],
]
const KIN := ["cindle", "pebbit", "zapple", "wisplet", "burrlet", "puddlet"]  # the six Hunters' Boki, in order
const GAP := 6.0  # m between the squads at the start
const LEAD_S := 2.0  # s of fight before the first counted frame
const EVERY_S := 1.0  # s between counted frames
const BODY_SHADERS := ["blob_shadow.gdshader", "wisp_core.gdshader", "boki_wisp.gdshader"]  # body looks, not fx
const NEAR_K := 1.0  # body widths round a Hunter's screen box that count as on it
## --clarity-check's element budget: "kind what" prefix -> the most element-Hunter pairs a frame, on average.
## Plates, ownership rings, telegraphs and your own damage numbers are gameplay and not held here.
const BUDGET := {
	"text": 1.0,  # words on a Hunter: only your own Boki's ability name, now and then (no callout words)
	"icon": 0.0,  # no world icon (Sprite3D) on a Hunter
	"hud grip_icons": 6.0,  # in a fight the glove row shows only the merge-ready glow
	"ring merge_look": 0.0,  # a ground ring means gameplay: the merge look wears none
}


## Plays fight `archs` (6 ids, yours first) and calls `on_frame(m, i)` on each of `frames` frames, the camera on it.
static func play(main: Node, archs: Array, frames: int, on_frame: Callable) -> Match:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["name"] = HeroTitle.base_name(archs[0])
	var m := Match.new()
	main.add_child(m)
	var o := {
		"teams": 2,
		"squad": 3,
		"total": 1,
		"tier": 1,
		"seed": 5,
		"length": 1e9,
		"no_drop": true,
		"map": MAP,
		"raid": "clear",
		"blight": false,
		"sim_keep": true,
		"demo_kin": KIN[0],
		"demo_kin_lv": "8:95"
	}
	o.merge({"arch": archs[0], "cls": Arch.weight(archs[0]), "weapon": Arch.signature(archs[0])}, true)
	m.start(o)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var p := m.player
	p.ctrl = "bot"
	p.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	var base := p.pos
	for i in range(1, 6):
		var side := 0 if i < 3 else 1
		var at := base + Vector3(GAP * side + 1.4 * (side * 2 - 1), 0, 1.6 * (1 - 2 * (i % 2)))
		at = m.world.free_spot_near(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), [], 1.2, 0.5, 6.0)
		var rec := Save.new_kin(KIN[i], "", i * 7919)
		rec["level"] = 8
		var kit := {"arch": archs[i], "weapon": Arch.signature(archs[i]), "perk": ""}
		var pname := HeroTitle.base_name(archs[i])
		var h := m.make_hunter("h%d" % i, side, Arch.weight(archs[i]), pname, "bot", rec, at, kit)
		h.unlock_all()
		h.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	for h: Hunter in m.hunters:  # each starts hit by a rival: bots leave a fresh rival alone unless provoked
		h.last_hit_by = m.hunters.filter(func(o): return o.team != h.team)[0]
	var t := 0.0
	var next := LEAD_S
	var i := 0
	while i < frames:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		m.cam.snap(_centre(m))
		await main.get_tree().process_frame
		t += DT
		if t >= next:
			SafeArea.seen.clear()  # the HUD's drawn marks (plates, icons, badges) are recorded for tally()
			SafeArea.recording = true
			m.hud.c.queue_redraw()
			m.hud.panels.queue_redraw()
			await main.get_tree().process_frame
			SafeArea.recording = false
			await on_frame.call(m, i)
			i += 1
			next += EVERY_S
	return m


## Every element over or near a Hunter this frame: [kind, what, hunter count] (kind: text, number, icon, ring, fx for
## the world; hud for a HUD mark recorded by SafeArea under its group, such as "plate" or "grip_icons").
static func tally(m: Match) -> Array:
	var zones: Array[Rect2] = []
	for h: Hunter in m.hunters:
		var z := HunterZone.rect_of(m, h)
		if z.has_area():
			zones.append(z.grow(z.size.x * NEAR_K))
	var out: Array = []
	for n in m.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		if not v.is_visible_in_tree() or _body(v):
			continue
		var on := _on(zones, _screen(m.cam, v))
		if on > 0:
			out.append([_kind(v), _what(v), on])
	for g: String in SafeArea.seen:
		for r: Rect2 in SafeArea.seen[g]:
			var on := _on(zones, r)
			if on > 0:
				out.append(["hud", g, on])
	return out


static func _on(zones: Array[Rect2], box: Rect2) -> int:
	var on := 0
	if box.has_area():
		for z in zones:
			if z.intersects(box):
				on += 1
	return on


static func _centre(m: Match) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for h: Hunter in m.hunters:
		if not h.out:
			c += h.pos
			n += 1
	return c / maxf(1.0, n)


## A Hunter's, Boki's or monster's own body (skinned or under a skeleton, a downed Hunter's or a Boki's wisp body,
## the blob shadow under a body: docs/COMBAT_CLARITY.md), the map itself, or an interactable's own badge
## (Models.icon_badge, a perk orb's icon: scenery a Hunter happens to stand in front of, not a mark on them).
static func _body(v: VisualInstance3D) -> bool:
	if v is Sprite3D:
		return String(v.name) == "Icon" or String(v.get_parent().name) == "Icon"
	if v is Label3D:
		return false
	var mi := v as MeshInstance3D
	if mi and mi.skin != null:
		return true
	if (
		mi
		and mi.material_override is ShaderMaterial
		and (mi.material_override as ShaderMaterial).shader
		and (mi.material_override as ShaderMaterial).shader.resource_path.get_file() in BODY_SHADERS
	):
		return true
	var p := v.get_parent()
	while p:
		if p is Skeleton3D or p is World:
			return true
		p = p.get_parent()
	return false


static func _screen(cam: Camera3D, v: VisualInstance3D) -> Rect2:
	var b := v.global_transform * v.get_aabb()
	var r := Rect2()
	var first := true
	for k in 8:
		var p := b.get_endpoint(k)
		if cam.is_position_behind(p):
			return Rect2()
		var s := cam.unproject_position(p)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


static func _kind(v: VisualInstance3D) -> String:
	if v is Label3D:
		var txt := (v as Label3D).text.strip_edges()
		return "number" if txt.lstrip("+-").is_valid_float() else "text"
	if v is Sprite3D:
		return "icon"
	var mi := v as MeshInstance3D
	var ringed := String(v.name).to_lower().contains("ring") or _what(v).contains("ring.gdshader")
	if mi and (mi.mesh is TorusMesh or ringed):
		return "ring"
	return "fx"


static func _what(v: VisualInstance3D) -> String:
	var n: Node = v
	while n and n.get_script() == null:
		n = n.get_parent()
	var by := (n.get_script() as Script).resource_path.get_file().get_basename() if n else "?"
	var nm := String(v.name).lstrip("@").rstrip("0123456789@")
	var w := "%s %s" % [by, "" if nm == v.get_class() else nm]
	if v is Label3D:
		return w + ("" if _kind(v) == "number" else " '%s'" % (v as Label3D).text.left(24))
	var mi := v as MeshInstance3D
	if mi and mi.mesh:
		var mat := mi.material_override if mi.material_override else mi.mesh.surface_get_material(0)
		var sh := ""
		if mat is ShaderMaterial and mat.shader:
			sh = (mat as ShaderMaterial).shader.resource_path.get_file()
		w += " <%s %s>" % [mi.mesh.get_class(), sh]
	return w
