class_name WardenSteps
extends RefCounted
## A Hero's step cue from its own clips (docs/AUDIO.md, Footsteps): each walk, run and crouch-walk loop has its foot
## plants in content/rules/step_contacts.json (the phase where each ankle reaches its lowest point as the game plays
## the loop; Motley, who floats, the low of his hips' bob), made by --step-contacts-gen. After the tree advances, the
## loop the legs mostly show is read; when the next advance (as long as the last one) carries it over a plant, the
## step is due, so the sound starts on the frame the foot is down. HunterAnim.stepped takes it (`take`).

const TABLE := "res://content/rules/step_contacts.json"
const DUE := "clip_step_due"    # model meta: the side of the step due (0 left, 1 right, 2 hips), or -1
const SPACES := {"loco": "parameters/loco/%d/clip/", "crouch_loco": "parameters/crouch_loco/%d/"}
const LEGS_ON := 0.5            # of the body the walk or run loops must show for a step to sound

static var _table: Variant = null

var model: Node3D
var tree: AnimationTree
var points := {}            # blend space name -> _space's points
var cur: Array = []         # the point read last frame, or [] when no loop showed
var ahead := 0.0            # 0..1: the phase the last look-ahead reached on `cur`


## The plants of every loop of art `art_name` (clip name -> [[phase, side], ...]), {} when it has none.
static func contacts(art_name: String) -> Dictionary:
	if _table == null:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
		_table = parsed if parsed is Dictionary else {}
	return (_table as Dictionary).get(art_name, {})


## The steps of `anim_tree`'s loops that `plants` (clip name -> [[phase, side], ...]) lists, or null when none.
static func make(root: Node3D, anim_tree: AnimationTree, plants: Dictionary) -> WardenSteps:
	if plants.is_empty():
		return null
	var s := WardenSteps.new()
	s.model = root
	s.tree = anim_tree
	var bt := anim_tree.tree_root as AnimationNodeBlendTree
	for sp in SPACES:
		if bt.has_node(sp):
			s.points[sp] = _space(bt.get_node(sp) as AnimationNodeBlendSpace2D, String(SPACES[sp]), plants)
	root.set_meta(DUE, -1)
	return s


## The step due on `root` (its side, or -1), cleared: HunterAnim's frame takes it before the clips advance again.
static func take(root: Node3D) -> int:
	var side := int(root.get_meta(DUE, -1))
	if side >= 0:
		root.set_meta(DUE, -1)
	return side


## After the tree advanced: `pos` the blend position of space `sp`, `legs_k` how much of the body its loops show.
func tick(sp: String, pos: Vector2, legs_k: float) -> void:
	var p := showing(sp, pos) if legs_k >= LEGS_ON else []
	if p.is_empty():
		cur = []
		return
	var u := phase(p)
	var to := u + absf(float(tree.get(p[3]))) / float(tree.get(p[2]))
	var from := ahead if is_same(p, cur) else u
	cur = p
	var span := fposmod(to - from, 1.0)
	if span > 0.5:      # (no advance this frame: the look-ahead already reached past it)
		return
	ahead = fposmod(to, 1.0)
	for c in p[4]:
		var off := fposmod(float(c[0]) - from, 1.0)
		if off > 0.0 and off <= span:
			model.set_meta(DUE, int(c[1]))


## The point of space `sp` nearest blend position `pos` (the loop the legs mostly show), or [] standing:
## [at, position path, length path, delta path, plants, clip name].
func showing(sp: String, pos: Vector2) -> Array:
	var best: Array = []
	var best_d := pos.length()      # (nearer the idle at the centre: no loop shows)
	for p in points.get(sp, []):
		var dist := pos.distance_to(p[0])
		if dist < best_d:
			best_d = dist
			best = p
	return best


## How far through its loop point `p` is (0..1).
func phase(p: Array) -> float:
	return fposmod(float(tree.get(p[1])) / float(tree.get(p[2])), 1.0)


## The blend points of a space whose clip `plants` lists (see `showing`).
static func _space(bs: AnimationNodeBlendSpace2D, path: String, plants: Dictionary) -> Array:
	var out: Array = []
	for i in bs.get_blend_point_count():
		var nd := bs.get_blend_point_node(i)
		if nd is AnimationNodeBlendTree:
			nd = (nd as AnimationNodeBlendTree).get_node("clip")
		var clip := String((nd as AnimationNodeAnimation).animation)
		if plants.has(clip):
			var at := path % i
			var paths := ["current_position", "current_length", "current_delta"].map(func(k): return StringName(at + k))
			out.append([bs.get_blend_point_position(i)] + paths + [plants[clip], clip])
	return out
