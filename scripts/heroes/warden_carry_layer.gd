class_name WardenCarryLayer
extends RefCounted
## One Hero's carry layer state (WardenCarry's maths, eased in and out), shared by the contract path (WardenClips) and
## Meshy's own skeleton (WardenNative). Two things ease separately: the arms (`arms_w`: both hands cradle the Boki at the
## socket) and the weapon (`away_w`: the data's "carry_stow" bones put away, a weapon modelled into a hand left off the
## shown mesh). A garden verb or a tool puts the weapon away without bringing the arms in.

var data: Dictionary                # "carry_stow", "carry_fwd", "carry_drop", "carry_drop_surfaces", "carry_back"
var arms_w := 0.0                   # how far the arms hold the Boki
var away_w := 0.0                   # how far the weapon is put away
var drop: Array = []                # WardenCarry.held: the body meshes whose weapon is in a hand (built when first needed)
var hands: Array = []               # the hands to look for that weapon on when the data names none
var _built := false
var _stowed := false


## The layer for a Hero's carry data; its "carry_drop" (hands) falls back to `hands`.
static func make(d: Dictionary, hands_to_check: Array = []) -> WardenCarryLayer:
	var layer := WardenCarryLayer.new()
	layer.data = d
	layer.hands = hands_to_check
	return layer


## Advances both eases. `arms` brings the hands in (writes the socket on `root`), `away` alone puts the weapon away.
## `back` is the Boki on the back: the hands hold it behind the hips instead of at the chest. True on the frame the
## weapon is fully back (the caller gives a weapon bone with a size of its own its size again).
func step(skel: Skeleton3D, root: Node3D, arms: bool, away: bool, back: bool, dt: float) -> bool:
	arms_w = move_toward(arms_w, 1.0 if arms else 0.0, dt / WardenCarry.FADE)
	away_w = move_toward(away_w, 1.0 if (arms or away) else 0.0, dt / WardenCarry.FADE)
	if arms_w <= 0.0:
		root.remove_meta(WardenCarry.SOCKET)
	else:
		var fwd := float(data.get("carry_fwd", WardenCarry.REACH_FWD))
		root.set_meta(WardenCarry.SOCKET, WardenCarry.apply(skel, root, arms_w, fwd, back))
	if away_w <= 0.0 and not _stowed:
		return false
	if not _built:
		_built = true
		drop = WardenCarry.held(skel, data.get("carry_drop", hands), data.get("carry_drop_surfaces", []))
	_stowed = away_w > 0.0
	WardenCarry.stow(skel, data.get("carry_stow", []), away_w)
	WardenCarry.hold(drop, away_w >= 0.5)
	return not _stowed
