class_name FirstUltHint
extends RefCounted
## The first time a save's hero ultimate is ready in a match, one hint through Match._tip (key "hero_ult", so
## once per save): "<key> is ready: <ult name>, <the first line of its text>". It never shows in a fight's
## first HOLD_S s of damage: a fight starts at the first hit the player takes or deals after QUIET_S s of none.

const KEY := "hero_ult"
const HOLD_S := 2.0       # s from a fight's first hit before the hint may show
const QUIET_S := 4.0      # s without a hit that end a fight
const LINE_MAX := 60      # chars of the ability text the hint keeps

var _m: Match = null
var _hit_at := -99.0
var _fight_at := -99.0

## Called from Match._tips each frame once tips run.
func tick(m: Match) -> void:
	if bool(Save.d["tutorial"].get(KEY, false)):
		return
	if _m == null:
		_m = m
		CombatBus.hit_landed.connect(_on_hit)
	var p := m.player
	if p.ak == null or p.downed or KinMerge.active(p) or not HeroUlt.ready(p.ak):
		return
	if m.time - _fight_at < HOLD_S:
		return
	m._tip(KEY, text(p.ak))

func _on_hit(by: Node, target: Node, _amount: float, _tags: Array) -> void:
	var p := _m.player
	if p == null or (by != p and target != p):
		return
	if _m.time - _hit_at >= QUIET_S:
		_fight_at = _m.time
	_hit_at = _m.time

## The hint for a kit's ult: its key cap, its name and the first sentence of its text, cut to LINE_MAX.
static func text(k: ArchKit) -> String:
	var xd := k.x_def()
	var line := short_line(String(xd.get("desc", "")))
	return "%s is ready: %s, %s" % [Settings.key_cap("hunter_ult"), String(xd.get("name", "")), line]

static func short_line(desc: String) -> String:
	var line := desc.get_slice(". ", 0).trim_suffix(".")
	line = line.left(1).to_lower() + line.substr(1)
	if line.length() <= LINE_MAX:
		return line
	var cut := line.left(LINE_MAX).rfind(" ")
	return line.left(cut if cut > 0 else LINE_MAX).trim_suffix(",") + "…"
