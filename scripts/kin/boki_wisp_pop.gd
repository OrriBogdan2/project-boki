class_name BokiWispPop
extends Node3D
## A Boki bursting out of its wisp and folding back into it (DECISIONS 2026-11-09: wisp mode, summon).
## It holds both looks: the wisp (BokiWispLook) and the Boki (Models.kin) in a `Form` node, and pose(u, out)
## sets them for progress u of one DURATION. Soft light only: the wisp swells and the Boki grows out of it,
## nothing else is spawned (no explosion, ring or disc: explosions are for things that truly explode).
##   Burst: the wisp swells, the Boki scales up out of it with overshoot, drops to `stand` and squashes on
##   landing, the eyes open last.
##   Fold: the eyes close first, the Boki shrinks into a wisp where it stands, and the wisp zips up to the
##   shoulder (this node's origin).
## Positions are relative to this node: the wisp's home is the origin, the Boki's feet land on `stand`.

signal finished(out: bool)      # a play() ended; out = the Boki is out (not folded away)

const DURATION := 0.25        # s, either way
const SWELL := 1.5            # x the wisp's size at its fullest
const BOKI_MID := 0.3         # m; the middle of a Boki above its feet at scale 1
const LAND_SQUASH := 0.2      # fraction of its height it flattens by landing (and anticipates folding by)
const GONE := 0.001           # a scale below this is hidden, never a zero scale
# burst, as fractions of DURATION
const BURST_SWELL_END := 0.4  # the wisp is at its fullest, then shrinks away
const BURST_WISP_GONE := 0.8
const BURST_FORM_FROM := 0.2  # the Boki starts to grow
const BURST_LANDS := 0.75     # the Boki has landed and settles
const BURST_EYES_OPEN := 0.8  # the lids lift from here to the end
# fold, as fractions of DURATION
const FOLD_LIDS_SHUT := 0.12
const FOLD_SHRINK_FROM := 0.1
const FOLD_SHRINK_TO := 0.6
const FOLD_WISP_FROM := 0.2   # the wisp starts to swell where the Boki folds
const FOLD_ZIP_FROM := 0.55   # then it zips up to the shoulder
const BACK := 1.7             # overshoot of the Boki's growth

var stand := Vector3.ZERO     # where the Boki's feet land, from the wisp's home
var wisp_k := 1.0             # the wisp's resting size (the Model Room shows them bigger)
var form_k := 1.0             # the Boki's size
var out := false              # the Boki is out (or bursting out)
var wisp: Node3D
var form: Node3D
var _puppet: KinPuppet
var _t := 0.0
var _p := 0.0
var _playing := false

func _init(species: String, rec := {}) -> void:
	wisp = BokiWispLook.build(species, rec)
	add_child(wisp)
	form = Node3D.new()
	form.name = "Form"
	var boki := Models.kin(species, rec)
	form.add_child(boki)
	for c in boki.get_children():
		if c is KinPuppet:
			_puppet = c
	add_child(form)
	pose(1.0, false)

## Burst out (true) or fold away (false) over DURATION. Ignored while one is playing.
func play(burst: bool) -> void:
	if _playing:
		return
	out = burst
	_p = 0.0
	_playing = true
	pose(0.0, burst)

func _process(dt: float) -> void:
	_t += dt
	BokiWispLook.pose(wisp, _t)
	if not _playing:
		return
	_p = minf(1.0, _p + dt / DURATION)
	pose(_p, out)
	if _p >= 1.0:
		_playing = false
		finished.emit(out)

## Sets both looks for progress u (0..1) of a burst (burst true) or a fold.
func pose(u: float, burst: bool) -> void:
	if burst:
		_burst(u)
	else:
		_fold(u)

func _burst(u: float) -> void:
	var swell := u / BURST_SWELL_END
	var w := lerpf(1.0, SWELL, ease(clampf(swell, 0.0, 1.0), 0.4))
	if u > BURST_SWELL_END:
		w = lerpf(SWELL, 0.0, ease(clampf((u - BURST_SWELL_END) / (BURST_WISP_GONE - BURST_SWELL_END), 0.0, 1.0), 2.0))
	_set_wisp(Vector3.ZERO, w)
	var grow := clampf((u - BURST_FORM_FROM) / (BURST_LANDS - BURST_FORM_FROM), 0.0, 1.0)
	var land := clampf((u - BURST_LANDS) / (1.0 - BURST_LANDS), 0.0, 1.0)
	var squash := LAND_SQUASH * sin(PI * land) * (1.0 - land)
	var home := Vector3(0, -BOKI_MID * form_k, 0)
	_set_form(home.lerp(stand, ease(grow, 2.0)), _back(grow), squash)
	_lids(1.0 - smoothstep(BURST_EYES_OPEN, 1.0, u))

func _fold(u: float) -> void:
	var shrink := ease(clampf((u - FOLD_SHRINK_FROM) / (FOLD_SHRINK_TO - FOLD_SHRINK_FROM), 0.0, 1.0), 2.0)
	var squash := LAND_SQUASH * sin(PI * clampf(u / FOLD_SHRINK_FROM / 2.0, 0.0, 1.0))
	var folded := stand + Vector3(0, BOKI_MID * form_k, 0)
	_set_form(stand.lerp(folded, shrink), 1.0 - shrink, squash)
	_lids(clampf(u / FOLD_LIDS_SHUT, 0.0, 1.0))
	var w := SWELL * ease(clampf((u - FOLD_WISP_FROM) / (FOLD_ZIP_FROM - FOLD_WISP_FROM), 0.0, 1.0), 0.5)
	var zip := clampf((u - FOLD_ZIP_FROM) / (1.0 - FOLD_ZIP_FROM), 0.0, 1.0)
	w = lerpf(w, 1.0, ease(zip, 0.5)) if zip > 0.0 else w
	_set_wisp(folded.lerp(Vector3.ZERO, ease(zip, -1.6)), w)

func _set_wisp(at: Vector3, k: float) -> void:
	wisp.position = at
	wisp.visible = k > GONE
	wisp.scale = Vector3.ONE * maxf(k, GONE) * wisp_k

func _set_form(at: Vector3, k: float, squash: float) -> void:
	form.position = at
	form.visible = k > GONE
	form.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5) * maxf(k, GONE) * form_k

## Eyes held shut by `shut` (0 open, 1 closed) on top of the Boki's own blinking.
func _lids(shut: float) -> void:
	if _puppet:
		_puppet.lids = shut

## Growth with overshoot (ease-out-back): 0 to 1, passing 1 and settling on it.
static func _back(x: float) -> float:
	return 1.0 + (BACK + 1.0) * pow(x - 1.0, 3.0) + BACK * pow(x - 1.0, 2.0)
