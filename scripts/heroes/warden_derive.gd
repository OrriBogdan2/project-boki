class_name WardenDerive
extends RefCounted
## A clip made from another clip's poses (data "derive" in content/rules/warden_anim/<art>.json), for a beat the
## .glb has no clip for: {name: {from, keys: [[t, src_t, {bone: [pitch, yaw, roll] degrees]}, ...]}}. Each key is the
## `from` clip's pose at src_t (s) with the bone turned by the offsets (in the bone's own frame), so a recovery starts
## on the strike's last pose and eases to its own settle. The clip is as long as its last key.

static func add(lib: AnimationLibrary, derive: Dictionary) -> void:
	for nm in derive:
		if lib.has_animation(StringName(nm)):
			continue            # (the .glb's library is shared by every model of the Hero: built once)
		var def: Dictionary = derive[nm]
		var src := lib.get_animation(String(def["from"]))
		var keys: Array = def["keys"]
		var out := Animation.new()
		out.length = float(keys[-1][0])
		for i in src.get_track_count():
			if src.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(src.track_get_path(i).get_concatenated_subnames())
			var tr := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(tr, src.track_get_path(i))
			for key in keys:
				var q: Quaternion = src.rotation_track_interpolate(i, float(key[1]))
				var turn: Array = (key[2] as Dictionary).get(bone, [])
				if not turn.is_empty():
					q *= Quaternion.from_euler(Vector3(deg_to_rad(turn[0]), deg_to_rad(turn[1]), deg_to_rad(turn[2])))
				out.rotation_track_insert_key(tr, float(key[0]), q)
		lib.add_animation(StringName(nm), out)
