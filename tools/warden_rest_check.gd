extends RefCounted
## --warden-rest-check: every Warden with a .glb has a baked rig rest (WardenRest, content/rules/warden_rest.json)
## equal to the one its procedural model measures now, so a match that reads the bake builds the .glb on the
## same armature; and every native art's baked contract reads (content/rules/warden_anchors.json: anchors, skeleton
## frame) equal what its contract .glb has now. --warden-rest-bake rewrites both (run it after changing a procedural
## rig or a contract .glb).

var bad := 0

func run(main: Node, mode: String) -> void:
	Save.no_write = true
	if mode == "bake":
		WardenRest.bake()
		print("WREST baked %s" % WardenRest.PATH)
	for a in Arch.ORDER:
		if not WardenGlb.has_model(a):
			continue
		var cur := WardenRest.same(WardenRest.baked(a), WardenGlb.measure_rest(a))
		if cur:
			print("WREST ok   %s" % a)
		else:
			print("WREST FAIL %s: stale or missing, run -- --warden-rest-bake" % a)
			bad += 1
	for art_name in WardenNative.arts():
		var baked: Dictionary = WardenRest.contracts().get(art_name, {})
		if WardenRest.same_contract(baked, WardenNative.measure_contract(art_name)):
			print("WREST ok   contract %s (%d anchors)" % [art_name, (baked.get("anchors", []) as Array).size()])
		else:
			print("WREST FAIL contract %s: stale or missing, run -- --warden-rest-bake" % art_name)
			bad += 1
	print("WREST DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
