class_name BokiWear
## Boki wear sold through the market (docs/decisions/0013-market.md) that Models.accessory doesn't
## draw itself: the studded collar and the star charm. Same body space as the other accessories.

static func build(body: Node3D, id: String, c: Color) -> void:
	match id:
		"collar":
			var band := Models.cyl(0.215, 0.215, 0.07, 18)
			Models.part(body, band, Models.toon(c), Vector3(0, 0.25, -0.02), Vector3(1.05, 1, 1.05))
			var stud := Models.toon(Color("e8e4dc"), true, 0.2)
			for i in 5:
				var a := PI * 0.5 + (float(i) - 2.0) * 0.42
				Models.part(body, Models.sphere(0.028, 6), stud, Vector3(cos(a) * 0.23, 0.25, -sin(a) * 0.23))
		"charm":
			var cord := Models.toon(Color("6b4a33"))
			var ring := Models.cyl(0.205, 0.205, 0.025, 16)
			Models.part(body, ring, cord, Vector3(0, 0.25, -0.02), Vector3(1.05, 1, 1.05))
			var glow := Models.toon(c, false, 0.9)
			for i in 5:
				var a := float(i) / 5.0 * TAU
				var tip := Vector3(sin(a) * 0.045, 0.15 + cos(a) * 0.045, -0.33)
				Models.part(body, Models.box(0.035, 0.11, 0.03), glow, tip, Vector3.ONE, Vector3(0, 0, -a))
			Models.part(body, Models.sphere(0.04, 8), glow, Vector3(0, 0.15, -0.335))
