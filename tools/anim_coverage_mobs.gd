extends RefCounted
## --anim-coverage-check, the monster rows: the seven common mobs through idle, walk, attack, hit and death
## (docs/ANIM_COVERAGE.md). `proc` is a keyed MobAnim table (MobAnim.MOVES; MobGlb copies it onto the bones of the
## kind's skinned art/mobs model), `missing` a state the monster is in with no table, `n/a` an attack a kind never makes
## (Data.MOBS attack "none"). `clip` is a .glb animation the game plays: nothing maps one for a mob, so a clip in a
## mob's .glb is printed as UNMAPPED. Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const COLS := ["idle", "walk", "attack", "hit", "death"]
## the MobAnim state each column plays; attack is the wind-up tell and, for a kind whose blow lasts, the strike
const STATES := {
	"idle": ["idle"], "walk": ["walk"], "attack": ["windup", "strike"], "hit": ["flinch"], "death": ["death"]
}


## The names of the animations baked into a .glb (its JSON chunk), empty when it has none.
static func glb_clips(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	f.seek(12)
	var n := f.get_32()
	f.seek(20)
	var j: Dictionary = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	return (j.get("animations", []) as Array).map(func(a): return String(a["name"]))


static func _cell(kind: String, col: String) -> String:
	var moves: Dictionary = MobAnim.MOVES.get(MobAnim.base_kind(kind), {})
	var need := false
	for s in STATES[col]:
		var state: int = MobAnim.STATES.find(s)
		if MobAnim.state_needed(kind, state):
			need = true
			if moves.get(s, []).is_empty():
				return "missing"
	return "proc" if need else "n/a"


## {kind: [cells]}; prints an UNMAPPED line for every clip in a mob's .glb.
static func rows() -> Dictionary:
	var out := {}
	for kind in KINDS:
		out[kind] = COLS.map(func(c): return _cell(kind, c))
		for c in glb_clips("res://art/mobs/%s/%s.glb" % [kind, kind]):
			print("UNMAPPED clip '%s' in art/mobs/%s/%s.glb" % [c, kind, kind])
	return out
