class_name WardenClipFile
extends RefCounted
## Clips kept beside a Hero's model in a clips-only .glb (data "clip_files" in content/rules/warden_anim/<art>.json;
## written by tools/art1/glb_clips_only.py): new clips for a Hero without its model .glb being re-exported. Each
## clip joins the Hero's library under its own name, its tracks pointed at the model's skeleton by bone name.


static func add(lib: AnimationLibrary, glb: Node3D, skel: Skeleton3D, files: Array) -> void:
	for file in files:
		var scene := (load(String(file)) as PackedScene).instantiate()
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var from := player.get_animation_library(player.get_animation_library_list()[0])
		for clip in from.get_animation_list():
			if not lib.has_animation(clip):  # (the model's library is shared by every model of the Hero)
				lib.add_animation(clip, _on_skeleton(from.get_animation(clip), glb.get_path_to(skel)))
		scene.free()


static func _on_skeleton(src: Animation, skel_path: NodePath) -> Animation:
	var out := src.duplicate() as Animation
	for i in out.get_track_count():
		var bone := out.track_get_path(i).get_concatenated_subnames()
		out.track_set_path(i, NodePath("%s:%s" % [skel_path, bone]))
	return out
