class_name CrouchHint
extends RefCounted
## The crouch lesson as one contextual line (the shorter tutorial drops its crouch step): the first time
## a new player walks up to a camp nobody has woken, the banner says what crouching is for. The text is
## the context-tips table's "crouch_camp" (content/rules/tips.json), so the key follows Settings.key_cap.
## It is only drawn (never pauses or blocks), goes after LIFE seconds (or when you crouch) and waits while
## the first-match guide has a line up. Once it has shown, or you were already crouching, the save's
## tutorial.crouch_hint keeps it from coming back.

const TIP := "crouch_camp"
const NEAR := 22.0  # m: this close to an idle camp monster the line comes up
const LIFE := 6.0  # s the line stays up at most
const LOOK_EVERY := 0.5  # s between scans of the monsters

var m: Match
var line := ""  # the line on screen ("" for none)
var _t := 0.0  # s the line has been up
var _look := 0.0  # s until the next scan


## The hint for a match that is a real Extraction and a save that hasn't had it yet, else null.
static func for_match(mt: Match, opts: Dictionary) -> CrouchHint:
	for skip in ["tutorial", "duel", "arena", "training"]:
		if opts.get(skip, false):
			return null
	if Save.d["tutorial"].get("crouch_hint", false) or not Settings.get_v("tips"):
		return null
	var h := CrouchHint.new()
	h.m = mt
	return h


## Old saves: one that has played already doesn't get the new-player hint.
static func migrate(data: Dictionary) -> void:
	var tut: Dictionary = data.get("tutorial", {})
	if not tut.has("crouch_hint") and int(data.get("matches", 0)) > 0:
		tut["crouch_hint"] = true
		data["tutorial"] = tut


func tick(dt: float) -> void:
	var p := m.player
	if p == null or p.out or p.extracted or p.downed or p.dropping:
		line = ""
		return
	if m.guide != null and m.guide.line != "":
		return  # the first-match guide owns the banner lane while it speaks
	if line != "":
		_t += dt
		if _t >= LIFE or p.crouch:
			m.crouch_hint = null
		return
	_look -= dt
	if _look > 0.0:
		return
	_look = LOOK_EVERY
	if not _camp_near(p):
		return
	Save.d["tutorial"]["crouch_hint"] = true
	if p.crouch:
		m.crouch_hint = null  # already doing it
		return
	line = TipPick.text(TIP)
	_t = 0.0


## Is an idle camp monster within NEAR (and so not yet alerted to you)?
func _camp_near(p: Hunter) -> bool:
	for mb: Mob in m.mobs:
		if mb is Blight or mb is Boss or mb.dead or mb.st != "idle" or mb.md.get("flee", false):
			continue
		if mb.flat_dist(p) <= NEAR and absf(mb.pos.y - p.pos.y) < 3.0:
			return true
	return false


func draw(h, sz: Vector2) -> void:
	if m.guide == null or m.guide.line == "":
		FirstMatchGuide.draw_line(h, sz, line, _t)
