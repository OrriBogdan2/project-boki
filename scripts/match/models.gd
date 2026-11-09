class_name Models

static var OUTLINE: Shader = ModelsBase.OUTLINE
static var RING: Shader = ModelsBase.RING
static var GLOW: Shader = ModelsBase.GLOW
static var HERO: Shader = ModelsBase.HERO
static func toon(c: Color, outline := true, glow := 0.0) -> ShaderMaterial:
	return ModelsBase.toon(c, outline, glow)
static func vtoon() -> ShaderMaterial:
	return ModelsBase.vtoon()
static func ring_mat(c: Color, thickness := 0.14) -> ShaderMaterial:
	return ModelsBase.ring_mat(c, thickness)
static func glow_mat(c: Color) -> ShaderMaterial:
	return ModelsBase.glow_mat(c)
static func part(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO, pname := "") -> MeshInstance3D:
	return ModelsBase.part(parent, mesh, mat, pos, scl, rot, pname)
static func sphere(r: float, seg := 16) -> SphereMesh:
	return ModelsBase.sphere(r, seg)
static func capsule(r: float, h: float) -> CapsuleMesh:
	return ModelsBase.capsule(r, h)
static func box(x: float, y: float, z: float) -> Mesh:
	return ModelsBase.box(x, y, z)
static func rounded_box(size: Vector3, r: float, steps := 3) -> ArrayMesh:
	return ModelsBase.rounded_box(size, r, steps)
static func _quad(verts: PackedVector3Array, norms: PackedVector3Array, idx: Array, a: int, b: int, c: int, d: int) -> void:
	ModelsBase._quad(verts, norms, idx, a, b, c, d)
static func lathe(profile: PackedVector2Array, seg := 24, key := "") -> ArrayMesh:
	return ModelsBase.lathe(profile, seg, key)
static func smooth_curve(pts: PackedVector2Array, sub := 4) -> PackedVector2Array:
	return ModelsBase.smooth_curve(pts, sub)
static func plain_cyl(top: float, bottom: float, h: float, seg := 14) -> CylinderMesh:
	return ModelsBase.plain_cyl(top, bottom, h, seg)
static func cyl(top: float, bottom: float, h: float, seg := 14) -> Mesh:
	return ModelsBase.cyl(top, bottom, h, seg)
static func eye_mesh(r: float, iris: Color, dark := Color("1a1620")) -> ArrayMesh:
	return ModelsBase.eye_mesh(r, iris, dark)
static func crystal(r: float, h: float, sides := 6) -> ArrayMesh:
	return ModelsBase.crystal(r, h, sides)
static func shiny(c: Color, gloss := 0.6) -> ShaderMaterial:
	return ModelsBase.shiny(c, gloss)
static func flat_quad(size: float) -> PlaneMesh:
	return ModelsBase.flat_quad(size)
const LOOK_SKIN := ModelsLook.LOOK_SKIN
const LOOK_HAIR := ModelsLook.LOOK_HAIR
const LOOK_GENDERS := ModelsLook.LOOK_GENDERS
const LOOK_FACES := ModelsLook.LOOK_FACES
const LOOK_HAIRS := ModelsLook.LOOK_HAIRS
const HAIR_FROM_OLD := ModelsLook.HAIR_FROM_OLD
static func hair_styles(race: int) -> Array:
	return ModelsLook.hair_styles(race)
const LOOK_OUTFITS := ModelsLook.LOOK_OUTFITS
const OUTFIT_COLS := ModelsLook.OUTFIT_COLS
const LOOK_DETAILS := ModelsLook.LOOK_DETAILS
const RACES := ModelsLook.RACES
const LOOK_RACES := ModelsLook.LOOK_RACES
static func default_look() -> Dictionary:
	return ModelsLook.default_look()
static func _pivot(torso: Node3D, nm: String, at: Vector3) -> Node3D:
	return ModelsLook._pivot(torso, nm, at)
static func hunter(cls: String, team_col: Color, weapon: String, outfit := "", appearance := {}, arch := "") -> Node3D:
	return ModelsHunter.hunter(cls, team_col, weapon, outfit, appearance, arch)
static func hero_look(sm: ShaderMaterial) -> void:
	ModelsHunter.hero_look(sm)
static func _spike(n: Node3D, m: Material, at: Vector3, dir: Vector3, r: float, h: float, flat := 1.0) -> MeshInstance3D:
	return ModelsHair._spike(n, m, at, dir, r, h, flat)
static func vtoon_outlined() -> ShaderMaterial:
	return ModelsBake.vtoon_outlined()
static func merge_static(node: Node3D) -> void:
	ModelsBake.merge_static(node)
static func bake_part_y(n: Node) -> void:
	ModelsBake.bake_part_y(n)
static func painted(m: ShaderMaterial, surface := 0, grad := 0.22, crease_k := 0.26, edge := 0.24) -> ShaderMaterial:
	return ModelsBake.painted(m, surface, grad, crease_k, edge)
static func _mat_key(m: Material) -> String:
	return ModelsBake._mat_key(m)
static func collect_mats(n: Node) -> Array:
	return ModelsBake.collect_mats(n)
static func prism_tip() -> PrismMesh:
	return ModelsFace.prism_tip()
static func gun_parts(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	ModelsGear.gun_parts(gun, weapon, m_gun, m_dark, m_acc)
static func gear_drop(col: Color, rar: int) -> Node3D:
	return ModelsGear.gear_drop(col, rar)
static func gear_pad(col: Color) -> Node3D:
	return ModelsGear.gear_pad(col)
static func gear_platform(col: Color) -> Node3D:
	return ModelsGear.gear_platform(col)
static func gear_smoke() -> Node3D:
	return ModelsGear.gear_smoke()
static func breakable(kind_s: String) -> Node3D:
	return ModelsGear.breakable(kind_s)
static var AURA: Shader = ModelsKin.AURA
static func aura_mat(c: Color, strength := 0.6) -> ShaderMaterial:
	return ModelsKin.aura_mat(c, strength)
static func kin(species: String, rec := {}) -> Node3D:
	return ModelsKin.kin(species, rec)
static func _repivot(n: Node3D, at: Vector3) -> void:
	ModelsKin._repivot(n, at)
static func accessory(body: Node3D, id: String, c: Color) -> void:
	ModelsKin.accessory(body, id, c)
static func air_ring() -> Node3D:
	return ModelsKin.air_ring()
static func training_yard() -> Node3D:
	return ModelsKin.training_yard()
static func nesting_nook() -> Node3D:
	return ModelsKin.nesting_nook()
static func nest_egg(c: Color, spot: Color) -> Node3D:
	return ModelsKin.nest_egg(c, spot)
static func incubator() -> Node3D:
	return ModelsKin.incubator()
static func rare_egg_small(spot: Color, s := 1.0) -> Node3D:
	return ModelsKin.rare_egg_small(spot, s)
static func mob(kind: String) -> Node3D:
	return ModelsWorld.mob(kind)
static func rock(rng: RandomNumberGenerator, s: float, moss := Color("6f9a4a")) -> Node3D:
	return ModelsWorld.rock(rng, s, moss)
static func tree(rng: RandomNumberGenerator, leaf: Color, style := "round") -> Node3D:
	return ModelsWorld.tree(rng, leaf, style)
static func grass_mesh(tall: bool) -> ArrayMesh:
	return ModelsWorld.grass_mesh(tall)
static func flower_mesh() -> ArrayMesh:
	return ModelsWorld.flower_mesh()
static func grass_material(sway: float, flower := false) -> ShaderMaterial:
	return ModelsWorld.grass_material(sway, flower)
static func chest() -> Node3D:
	return ModelsWorld.chest()
static func deathbox(col: Color) -> Node3D:
	return ModelsWorld.deathbox(col)
static func icon_badge(kind: String, height: float, size := 0.8) -> Node3D:
	return ModelsWorld.icon_badge(kind, height, size)
static func revive_beacon() -> Node3D:
	return ModelsWorld.revive_beacon()
static func shrine() -> Node3D:
	return ModelsWorld.shrine()
static func nest() -> Node3D:
	return ModelsWorld.nest()
static func portal(c: Color) -> Node3D:
	return ModelsWorld.portal(c)
static func jump_pad(c: Color) -> Node3D:
	return ModelsWorld.jump_pad(c)
static func gem() -> Node3D:
	return ModelsWorld.gem()
static func armor_shard() -> Node3D:
	return ModelsWorld.armor_shard()
static func tonic() -> Node3D:
	return ModelsWorld.tonic()
static func seed_bag(c: Color) -> Node3D:
	return ModelsWorld.seed_bag(c)
static func house() -> Node3D:
	return ModelsHome.house()
static func plot() -> Node3D:
	return ModelsHome.plot()
static func crop(stage: int, grow: int, col: Color) -> Node3D:
	return ModelsHome.crop(stage, grow, col)
static func cauldron() -> Node3D:
	return ModelsHome.cauldron()
static func stall() -> Node3D:
	return ModelsHome.stall()
static func fence(length: float) -> Node3D:
	return ModelsHome.fence(length)
static func lamp() -> Node3D:
	return ModelsHome.lamp()
static func pond(rx: float, rz: float) -> Node3D:
	return ModelsHome.pond(rx, rz)
static func flower_bed(rng: RandomNumberGenerator, n := 7) -> Node3D:
	return ModelsHome.flower_bed(rng, n)
static func kin_bed(c: Color) -> Node3D:
	return ModelsHome.kin_bed(c)
static func signpost(text_lines: Array) -> Node3D:
	return ModelsHome.signpost(text_lines)
static func building(id: String) -> Node3D:
	return ModelsHome.building(id)
static func lot(w: float, d: float, title: String, price: String) -> Node3D:
	return ModelsHome.lot(w, d, title, price)
static func plank(rng: RandomNumberGenerator, width: float) -> MeshInstance3D:
	return ModelsHome.plank(rng, width)
static func ferry_post() -> Node3D:
	return ModelsHome.ferry_post()
static func lighthouse(col: Color) -> Node3D:
	return ModelsHome.lighthouse(col)
static func banner(col: Color) -> Node3D:
	return ModelsHome.banner(col)
static func notice_board() -> Node3D:
	return ModelsHome.notice_board()
static func fountain() -> Node3D:
	return ModelsHome.fountain()
static func furniture(id: String) -> Node3D:
	return ModelsHome.furniture(id)
static func float_island(rng: RandomNumberGenerator, radius: float, depth: float, top_c := Color("6aa64a"), side_c := Color("8b6d52"), deep_c := Color("3a3140")) -> MeshInstance3D:
	return ModelsScenery.float_island(rng, radius, depth, top_c, side_c, deep_c)
static func waterfall(width: float, height: float) -> Node3D:
	return ModelsScenery.waterfall(width, height)
static func skyship() -> Node3D:
	return ModelsScenery.skyship()
