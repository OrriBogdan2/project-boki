class_name RoomPieces
extends RefCounted
## The two pieces of furniture that do something when you stand next to them: the Boki journal and the gramophone.
## They are ordinary furniture (placed, moved and stored like the rest); this is their look and what they open.

const USES := {"journal": "Read the Boki journal", "gramophone": "Play some music"}

static func is_usable(id: String) -> bool:
	return USES.has(id)

## The model, built in a 1 x 1 tile box like the rest of the furniture.
static func model(id: String) -> Node3D:
	var root := Node3D.new()
	var wood := Models.toon(Color("7a5236"))
	if id == "journal":
		Models.part(root, Models.box(0.5, 1.0, 0.4), wood, Vector3(0.5, 0.5, 0.5))
		var page := Models.toon(Color("f1e6cf"))
		Models.part(root, Models.box(0.6, 0.06, 0.45), page, Vector3(0.5, 1.04, 0.5), Vector3.ONE, Vector3(-0.3, 0, 0))
	else:
		Models.part(root, Models.box(0.6, 0.7, 0.5), wood, Vector3(0.5, 0.35, 0.5))
		Models.part(root, Models.cyl(0.25, 0.25, 0.03, 18), Models.toon(Color("1e1e24")), Vector3(0.5, 0.72, 0.5))
		var brass := Models.toon(Color("d9b04a"), false, 0.3)
		Models.part(root, Models.cyl(0.05, 0.3, 0.45, 14), brass, Vector3(0.62, 1.05, 0.45), Vector3.ONE,
			Vector3(-0.6, 0, 0))
	return root
