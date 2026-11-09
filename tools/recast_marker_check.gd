extends "res://tools/hero_pair_check.gd"
## --recast-marker-check: the world marker of an open recast (scripts/ui/recast_marker.gd) on Motley's seed,
## Meeko's Hearthlight, Albert's thrown hammer and Sable's dagger: it shows the right key at the object, in
## the hero colour, for the caster only (a ring with no fill), fades in the last 0.5 s, and goes when the
## recast is used. --recast-marker-shots --shots-dir=<dir> (needs a renderer) saves one PNG per hero.

var out := ""

func run(main_node: Node, mode: String = "check") -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(out)
	for arch in ["ostra", "tender", "bulwark", "thief"]:
		await _hero(arch, mode == "shots")
	print("PAIRCHECK recast-marker DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Opens the hero's recast and steps until the thing to trigger exists.
func _open(K: ArchKit, m: Match, arch: String) -> void:
	if arch == "bulwark":
		(K as BulwarkKit)._throw()
		step(m, 1.2)
	else:
		K.use_e()
		step(m, 1.0)

func _hero(arch: String, shot: bool) -> void:
	var r := setup(arch, 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: ArchKit = P.ak
	ok("%s: no marker before the recast" % arch, not K.recast_at().is_finite() and m.get_node_or_null("RecastMarker") == null)
	_open(K, m, arch)
	var mark := m.get_node_or_null("RecastMarker") as RecastMarker
	ok("%s: marker on the object" % arch, K.recast_at().is_finite() and mark != null and mark.visible)
	if mark == null:
		return
	var key := Settings.key_cap(K.recast_key())
	ok("%s: shows the recast key %s" % [arch, key], mark.text == key and key != "?")
	ok("%s: key sits over the object" % arch, mark.global_position.distance_to(K.recast_at() + Vector3(0, RecastMarker.CAP_UP, 0)) < 0.01)
	var ring := AimKit.entry(P, "recast")
	ok("%s: caster-only ring, no fill" % arch, not ring.is_empty() and not bool(ring["all"]) and ring["kind"] == "ring")
	ok("%s: hero colour" % arch, (ring["col"] as Color).is_equal_approx(AimKit.hero_col(P)))
	ok("%s: full strength mid-window" % arch, is_equal_approx(mark.modulate.a, 1.0))
	if shot:
		await _shoot(m, arch)
	if arch != "bulwark":
		K.e_t = RecastMarker.FADE * 0.5
		RecastMarker.sync(K)
		ok("%s: fades in the last 0.5 s" % arch, is_equal_approx(mark.modulate.a, 0.5))
		K.e_t = 5.0
	if arch == "bulwark":
		(K as BulwarkKit)._recall()
	else:
		K.e_recast()
	step(m, 0.3)
	for i in 2:         # the marker hides itself in its next _process
		await main.get_tree().process_frame
	ok("%s: marker gone once used" % arch, not K.recast_at().is_finite() and not mark.visible)
	m.queue_free()

func _shoot(m: Match, arch: String) -> void:
	for i in 12:
		m.step(DT)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % arch))
