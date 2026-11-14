class_name HeroVfxFist
extends RefCounted
## The mesh of the "fist" layer (docs/HERO_VFX.md): a closed fist hanging knuckles-down, one unit wide, its
## knuckles at y = 0 and the wrist about 1.5 up. Built once from the shared rounded boxes.

static var _mesh: ArrayMesh = null

## [size, centre] of each part: the four knuckles, the back of the hand, the thumb across the front, the wrist.
const PARTS := [
	[Vector3(0.23, 0.42, 0.5), Vector3(-0.36, 0.21, 0.0)], [Vector3(0.23, 0.46, 0.5), Vector3(-0.12, 0.23, 0.0)],
	[Vector3(0.23, 0.46, 0.5), Vector3(0.12, 0.23, 0.0)], [Vector3(0.23, 0.4, 0.5), Vector3(0.36, 0.2, 0.0)],
	[Vector3(0.98, 0.5, 0.72), Vector3(0.0, 0.66, -0.04)], [Vector3(0.62, 0.2, 0.2), Vector3(-0.08, 0.34, 0.32)],
	[Vector3(0.62, 0.8, 0.56), Vector3(0.0, 1.3, -0.06)]]

static func fist_mesh() -> ArrayMesh:
	if _mesh == null:
		var st := SurfaceTool.new()
		for part: Array in PARTS:
			var extent: Vector3 = part[0]
			st.append_from(Models.box(extent.x, extent.y, extent.z), 0, Transform3D(Basis.IDENTITY, part[1]))
		_mesh = st.commit()
	return _mesh
