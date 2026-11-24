class_name ShopModels
extends RefCounted
## A vendor's stall: a counter under a striped awning in the stock theme's colour, with a lantern
## that bobs above it and the vendor's name floating over it. Procedural, like the rest of the props.

static func stall(theme_id: String) -> Node3D:
	var th := ShopStock.theme(theme_id)
	var col := Color(String(th.get("col", "ffffff")))
	var root := Node3D.new()
	var wood := Models.toon(Color("8a6a48"))
	var cloth := Models.toon(col.darkened(0.15), false)
	var cloth_b := Models.toon(Color("f3eee2"), false)
	Models.part(root, Models.box(2.2, 0.8, 0.8), wood, Vector3(0, 0.4, 0))
	Models.part(root, Models.box(2.4, 0.08, 1.0), Models.toon(Color("b08a5c")), Vector3(0, 0.84, 0))
	for sx in [-1.0, 1.0]:
		Models.part(root, Models.cyl(0.05, 0.05, 2.1, 8), wood, Vector3(sx * 1.1, 1.05, -0.35))
	for i in 5:
		var stripe := cloth if i % 2 == 0 else cloth_b
		var at := Vector3(-0.96 + i * 0.48, 2.05, -0.1)
		Models.part(root, Models.box(0.48, 0.06, 1.3), stripe, at, Vector3.ONE, Vector3(0.28, 0, 0))
	var bob := Node3D.new()
	bob.name = "Bob"
	bob.position = Vector3(0, 2.7, 0)
	root.add_child(bob)
	Models.part(bob, Models.sphere(0.2, 12), Models.toon(col, true, 0.9))
	var lb := Label3D.new()
	lb.text = String(th.get("name", ""))
	lb.font = UI.big
	lb.font_size = 30
	lb.pixel_size = 0.0085
	lb.outline_size = 10
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = Vector3(0, 0.55, 0)
	bob.add_child(lb)
	return root
