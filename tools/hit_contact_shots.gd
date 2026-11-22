extends RefCounted
## --hit-contact-shots --shots-dir=<dir> --tag=<name>: the frame a hit lands, for a Vex shot, a Kael strike and a
## Cinder zone tick on a tall (Grimble, 2.56 m) and a small (Meeko, 1.04 m) Hunter, one crop each, saved as
## <tag>_<target>_<kit>.png. Run under xvfb with a renderer, on the tree before and after HitContact.

const KITS := [["gunslinger", "lmb"], ["juggernaut", "lmb"], ["ashwick", "zone"]]
const TARGETS := ["dredge", "tender"]
const CROP := Vector2i(320, 240)  # px round the target, shown 2x
const MAX_STEPS := 90

var m: Match
var main: Node
var p: Hunter
var home := Vector3.ZERO


func run(main_node: Node) -> void:
	main = main_node
	var out := ""
	var tag := "shot"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	Save.d = Save.fresh()
	var ac: RefCounted = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = await ac.setup("mage", 30.0)
	m = r[0]
	p = r[1]
	home = r[4]
	(r[2] as Hunter).teleport(home + Vector3(-6.0, 0, -8.0))
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	for tarch in TARGETS:
		var spot := home + Vector3(-6.0, 0, 6.0)
		var t := m.make_hunter("T_" + tarch, 5, Arch.weight(tarch), "Target", "idle", {}, spot, {"arch": tarch})
		t.reclass(Arch.weight(tarch), tarch)
		t.max_hp = 1e6
		for k in KITS:
			var img := await _shot(k[0], k[1], t)
			img.save_png(out.path_join("%s_%s_%s.png" % [tag, tarch, k[0]]))
		t.teleport(home + Vector3(-30, 0, 30))
	print("HITCONTACT shots %s in %s" % [tag, out])
	main.get_tree().quit()


func _step() -> void:
	m.step(Match.DT)
	for h in m.hunters:
		h.render(Match.DT, 1.0)
	await main.get_tree().process_frame


## One hit: the hero fires (or Cinder's patch ticks) at `t`; the frame after its health drops is cropped round it.
func _shot(arch: String, kind: String, t: Hunter) -> Image:
	p.reclass(Arch.weight(arch), arch)
	p.unlock_all()
	p.lvl = 6
	p.teleport(home)
	p.vel = Vector3.ZERO
	m.shots.clear()
	m.fields.list.clear()
	var spot := home + Vector3(1.6 if kind == "zone" else 3.0, 0, 0)
	t.teleport(spot)
	t.hp = t.max_hp
	var mid := spot + Vector3(0, Arch.hit_h(t.arch) * 0.5, 0)
	p.inp["aim"] = mid
	p.inp["aim_y"] = mid.y
	p.face = -PI * 0.5
	m.cam.snap(mid)
	if kind == "zone":
		var patch := {"radius": 2.0, "dmg": 5.0, "every": 0.2, "time": 3.0, "color": "#ff7a30"}
		m.fields.add(p, spot, patch, {"slot": "zone"}, 1.0)
	else:
		p.fire_cd = 0.0
		p.ammo = int(p.wpn.get("mag", 99))
		p.atk.fire()
	var n := 0
	while t.hp >= t.max_hp and n < MAX_STEPS:
		await _step()
		n += 1
	await _step()
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(Rect2i(img.get_size() / 2 - CROP / 2, CROP))
	crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	print("HITCONTACT %s on %s: hit after %d steps" % [arch, t.arch, n])
	return crop
