extends RefCounted
## Camera framing and bookkeeping for `--clip-shots --proof` (hunter-proof): LIVE and a candidate are filmed from the
## same three cameras, sized from one figure height (--fig-h), so a bigger or smaller candidate shows its true size.
## clip_shots.gd prints FIGURE_H (the model's height, m) and FIGURE_FRAC (its share of the panel's height, per view),
## both counted in pixels against a flat backdrop.

const MATCH_DIST := 23.0  # m: the game's own camera (clip_shots STATE_VIEWS "match": 21 up, 9.4 back)
const MATCH_FOV := 8.0
const EYE_FOV := 30.0
const EYE_Y := 1.6  # m: a standing person's eyes
const KNEE_Y := 0.45  # m: knee height, looking up at the hunter
const FILL := 0.55  # the share of the panel's height a hunter fills (the proof rule is at least 0.40)
const MIN_FRAC := 0.40


## The share of the image's height that is not the backdrop: rows holding a pixel unlike the top-left corner.
static func rows_frac(img: Image) -> float:
	var bg := img.get_pixel(0, 0)
	var lo := -1
	var hi := -1
	for y in img.get_height():
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.12:
				if lo < 0:
					lo = y
				hi = y
				break
	return 0.0 if lo < 0 else float(hi - lo + 1) / float(img.get_height())


## The figure's height, m, from a probe frame of `frac` of the image's height filmed at EYE_FOV from `dist` m.
static func height_from(frac: float, dist: float) -> float:
	return frac * 2.0 * dist * tan(deg_to_rad(EYE_FOV) * 0.5)


## [fov, camera position, look-at] per view for a figure `h` m tall.
static func views(h: float) -> Dictionary:
	var look := Vector3(0.0, h * 0.5, 0.0)
	var game := Vector3(0.0, 21.0, 9.4).normalized()
	var match_d := minf(MATCH_DIST, _fit(h, MATCH_FOV))
	var eye_d := _fit(h, EYE_FOV)
	return {
		"match": [MATCH_FOV, game * match_d + Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.8, 0.0)],
		"eye": [EYE_FOV, Vector3(0.0, EYE_Y, eye_d), look],
		"knee": [EYE_FOV, Vector3(0.0, KNEE_Y, eye_d), look],
	}


## The camera's distance so a figure `h` m tall fills FILL of the panel's height.
static func _fit(h: float, fov_deg: float) -> float:
	return h / FILL / 2.0 / tan(deg_to_rad(fov_deg) * 0.5)


## <dir>/manifest.tsv: one `name<TAB>first frame<TAB>count` row per clip in the dir's f###.png run.
static func write_manifest(dir: String, segs: Array) -> void:
	var f := FileAccess.open(dir.path_join("manifest.tsv"), FileAccess.WRITE)
	for s in segs:
		f.store_line("%s\t%d\t%d" % [s[0], s[1], s[2]])
