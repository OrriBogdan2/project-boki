extends RefCounted
## Pre-render asset check for the film tools (private, never shipped). A clip is staged, then `enforce()` lists every
## hunter and Boki model on screen and the debug/HUD overlays that are on; any problem prints
## `CLIP_PREFLIGHT FAIL <why>`
## and the run quits with EXIT_CODE before a frame is filmed (r1-r3 of the garden friend film and garden worlds r7
## showed a placeholder hunter, an old Motley glb, and stray overlays: the camera was fine, the assets were not).
## - The cloaked "unmasked" starter (a procedural body by design) counts as a placeholder unless `allow_unmasked`
##   (the hunter-select screen shows it on purpose).
## - A hunter (a visible model root with metas "arch" and "glb") fails when it is the procedural placeholder body
##   (neither meta glb nor meshy_native) or when the glb the game draws for it (WardenGlb.path) is not byte-for-byte
##   the glb named in <v95 dir>/<Name>/current.json (HUNTER MODELS: /home/boki/meshy/v95; override with env
##   BOKI_V95_DIR; a box without that folder skips this one test and prints a NOTE).
## - A Boki (a visible "Flex" body) fails when it has no rigged model (BokiRig): KinModels drew its primitive spheres.
## - Overlays fail when Settings > show frame rate is on, Record is below `min_record` (1 clean HUD, 2 no HUD; 0 lets
##   the HUD show) or, for a clean clip, tips are on, the viewport draws a debug mode or the tree draws collision,
##   navigation or path hints.

const EXIT_CODE := 3
const V95_DIR := "/home/boki/meshy/v95"
## art name (WardenGlb.ART) -> its folder under the v95 dir (same table as /home/boki/bin/v95-sync-main)
const V95_NAME := {
	"claire": "claire",
	"ostra": "Motley",
	"breaker": "Albert",
	"hem": "lace",
	"ryzz": "Sparkle",
	"dredge": "Grimble",
	"gil": "Gil",
	"tarek": "tarek",
	"pip": "Meeko",
	"kael": "Kael",
	"vex": "Vex",
	"cinder": "Cinder",
	"sable": "Sable"
}


## Prints every problem and quits the game with EXIT_CODE when there is one; true when the scene is clean.
static func enforce(main: Node, min_record := 1, tag := "clip", allow_unmasked := false) -> bool:
	var bad := problems(main.get_tree().root, min_record, allow_unmasked)
	if bad.is_empty():
		print("CLIP_PREFLIGHT OK %s" % tag)
		return true
	for p in bad:
		print("CLIP_PREFLIGHT FAIL %s: %s" % [tag, p])
	main.get_tree().quit(EXIT_CODE)
	return false


## Every problem with the models and overlays under `root` (empty when clean).
static func problems(root: Node, min_record := 1, allow_unmasked := false) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}  # art name -> its glb verdict, so each file is hashed once
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Node3D and (n as Node3D).is_visible_in_tree():
			_model(n as Node3D, seen, out, allow_unmasked)
		elif n is PerfOverlay and (n as Control).is_visible_in_tree():
			out.append("frame-rate overlay is showing (%s)" % n.get_path())
	out.append_array(overlays(root, min_record))
	return out


static func overlays(root: Node, min_record := 1) -> PackedStringArray:
	var out := PackedStringArray()
	if Settings.fps_mode() != "":
		out.append("Settings show_fps is on (%s)" % Settings.fps_mode())
	if min_record > 0 and bool(Settings.v.get("tips", true)):
		out.append("Settings tips are on")
	if Record.level < min_record:
		out.append("Record level %d, the clip needs %d or more (1 clean HUD, 2 no HUD)" % [Record.level, min_record])
	var tree := root.get_tree()
	if root.get_viewport().debug_draw != Viewport.DEBUG_DRAW_DISABLED:
		out.append("viewport debug_draw is %d" % root.get_viewport().debug_draw)
	if tree.debug_collisions_hint or tree.debug_navigation_hint or tree.debug_paths_hint:
		out.append("the tree draws collision, navigation or path hints")
	return out


## The problem with a hunter's drawn glb ("" when it is the current v95 one): `path` is the file the game loads for
## `art` (WardenGlb.art name), `v95_dir` the folder holding <Name>/current.json.
static func glb_problem(art: String, path: String, v95_dir: String) -> String:
	if not V95_NAME.has(art):
		return "%s has no v95 folder in V95_NAME" % art
	var cur := "%s/%s/current.json" % [v95_dir, V95_NAME[art]]
	var named: Variant = JSON.parse_string(FileAccess.get_file_as_string(cur))
	if typeof(named) != TYPE_DICTIONARY or not FileAccess.file_exists(String(named.get("glb", ""))):
		return "%s: %s is missing or names no file" % [art, cur]
	var want := String(named["glb"])
	if FileAccess.get_sha256(path) != FileAccess.get_sha256(want):
		return "%s draws %s, not the v95 current %s" % [art, path, want]
	return ""


## A hunter root is dressed in a glb when WardenGlb set "glb" (contract rig) or WardenNative set "meshy_native".
static func _dressed(n: Node3D) -> bool:
	return bool(n.get_meta("glb", false)) or bool(n.get_meta(WardenNative.META, false))


static func _model(n: Node3D, seen: Dictionary, out: PackedStringArray, allow_unmasked: bool) -> void:
	if n.name == "Flex" and n.get_node_or_null("BokiRig") == null:
		out.append("Boki body %s is the primitive placeholder (no rigged model)" % n.get_path())
	if not (n.has_meta("arch") and n.has_meta("glb")):
		return
	var arch := String(n.get_meta("arch"))
	if arch == "unmasked" and allow_unmasked:
		return
	var art := String(WardenGlb.ART.get(arch, arch))
	if not _dressed(n):
		out.append("hunter %s (%s) is the procedural placeholder body" % [arch, n.get_path()])
	elif not seen.has(art):
		var dir := OS.get_environment("BOKI_V95_DIR") if OS.has_environment("BOKI_V95_DIR") else V95_DIR
		if DirAccess.dir_exists_absolute(dir):
			seen[art] = glb_problem(art, WardenGlb.path(arch), dir)
		else:
			seen[art] = ""
			print("CLIP_PREFLIGHT NOTE %s not found: hunter glbs not checked against current.json" % dir)
		if seen[art] != "":
			out.append(String(seen[art]))
