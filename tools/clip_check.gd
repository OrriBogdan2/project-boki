extends RefCounted
## --clip-check [--warden=<id>]: a Hero's hand-keyed clips (content/rules/warden_anim/<art>.json, WardenClips)
## against its kit and the ART-1 budget. Per Hero with a data file: every clip the data names is in the .glb; every
## keyed move of its kit has a clip, as long as the move's last key; the states have clips; the model stays in the
## tri budget; a skinned weapon draws one weapon only; and through each kit clip the FX point stays on the visible
## fist or blade (item 76b).

const MAX_TRIS := 20000       # incl. weapon and props (ART-1 brief; S1's perf findings set no lower number yet)
const TIME_TOL := 0.08        # s a clip may run short of its move's last key
const FX_TOL := 0.05          # m: the Muzzle from the tip empty it follows
## The keyed-move prefix of each Hero, as in tools/rig_standard_check.gd.
const CHECK := preload("res://tools/rig_standard_check.gd")

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CLIPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warden="):
			only = a.substr(9)
	var holder := Node3D.new()
	main.add_child(holder)
	for id in Arch.ids():
		if (only == "" or only == String(id)) and not WardenClips.data(WardenGlb.art(String(id))).is_empty():
			_hero(String(id), holder)
	print("CLIP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String, holder: Node3D) -> void:
	var d := WardenClips.data(WardenGlb.art(id))
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	var clips: WardenClips = sync.get("clips") if sync else null
	ok(clips != null, "%s: plays its .glb's clips" % id)
	if clips == null:
		m.free()
		return
	_names(id, d, clips)
	_moves(id, d, clips)
	_tris(id, m)
	_one_weapon(id, d, m)
	_fx(id, d, m, sync, clips)
	m.free()

## Every clip name the data uses.
func _names(id: String, d: Dictionary, clips: WardenClips) -> void:
	var want: Array = []
	var lc: Dictionary = d["loco"]
	want.append_array([lc["idle"], lc["stance"]])
	want.append_array((lc["walk"] as Dictionary).values())
	want.append_array((lc["run"] as Dictionary).values())
	want.append_array((d["air"] as Dictionary).values())
	want.append((d["land"] as Dictionary)["clip"])
	for k in d["kmoves"]:
		want.append(d["kmoves"][k]["clip"])
	for k in d["states"]:
		var v = d["states"][k]
		if v is Dictionary:
			want.append_array([v["front"], v["back"]])
		else:
			want.append(v)
	var missing: Array = want.filter(func(c): return not clips.lib.has_animation(String(c)))
	ok(missing.is_empty(), "%s: all %d clips the data names are in the .glb %s" % [id, want.size(), str(missing)])

## The kit's keyed moves all have a clip that lasts as long as the move.
func _moves(id: String, d: Dictionary, clips: WardenClips) -> void:
	var pre := String(CHECK.PREFIX[id])
	var absent: Array = []
	var short: Array = []
	var n := 0
	for t in CHECK.MOVE_TABLES:
		for mv in t:
			if not String(mv).begins_with(pre):
				continue
			n += 1
			if not (d["kmoves"] as Dictionary).has(mv):
				absent.append(mv)
				continue
			var keys: Array = HunterAnim.km_def(mv)["keys"]
			var length := clips.lib.get_animation(String(d["kmoves"][mv]["clip"])).length
			if length + TIME_TOL < float(keys[keys.size() - 1][0]):
				short.append("%s %.2f" % [mv, length])
	ok(absent.is_empty(), "%s: all %d kit moves have a clip %s" % [id, n, str(absent)])
	ok(short.is_empty(), "%s: each clip lasts its move %s" % [id, str(short)])

func _tris(id: String, m: Node3D) -> void:
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var ix: PackedInt32Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX]
			tris += ix.size() / 3
	ok(tris <= MAX_TRIS, "%s: %d tris, weapon and props in (budget %d)" % [id, tris, MAX_TRIS])

func _one_weapon(id: String, d: Dictionary, m: Node3D) -> void:
	if not bool(d.get("skinned_weapon", false)):
		return
	var shown: Array = []
	for mi in m.get_node("Rig/Torso/Aim/Gun").find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).visible:
			shown.append(mi.name)
	ok(shown.is_empty(), "%s: one weapon only, the skinned one %s" % [id, str(shown)])

## Through every kit clip the Gun's Muzzle, which shots and swings leave from, sits on the weapon you see.
func _fx(id: String, d: Dictionary, m: Node3D, sync: Node, clips: WardenClips) -> void:
	if not d.has("blade"):
		return
	var tip := WardenGlb.anchor(m, String(d["blade"]["tip"]))
	var muzzle := m.get_node("Rig/Torso/Aim/Gun/Muzzle") as Node3D
	var worst := 0.0
	var where := ""
	sync.set_process(false)
	for mv in d["kmoves"]:
		var clip := String(d["kmoves"][mv]["clip"])
		var length := clips.lib.get_animation(clip).length
		for i in 6:
			clips.force = {"clip": clip, "t": length * i / 6.0}
			sync.call("_process", 1.0 / 30.0)
			var off := muzzle.global_position.distance_to(tip.global_position)
			if off > worst:
				worst = off
				where = "%s @%d" % [clip, i]
	clips.force = {}
	ok(worst <= FX_TOL, "%s: the FX point stays on the visible weapon (worst %.3f m, %s)" % [id, worst, where])
