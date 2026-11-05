class_name MatchTips
extends RefCounted
## First-time tips on an expedition, and the short reminder card for something that can't work.
## A tip is one line in the message lane, shown the first time its moment comes up and never again on
## this save; it goes into the Tips log (Save.d["tips"], oldest first; TipsLog lists it from the pause
## menu). The words are content/rules/tips.json. What the Trial Expedition teaches isn't a tip, and the
## Trial itself shows none. Match owns one of these as `tips` and calls tick() every frame.

## Tips the Trial teaches now: an old save's flags for them are dropped (migrate).
const TAUGHT := ["move", "ability", "throw", "exit_uplink"]

var m: Match
var remind_text := ""        # the reminder card's line
var remind_t := 0.0          # s left of it

func _init(match_node: Match) -> void:
	m = match_node

## Tip id -> its line, from the data.
static func lines() -> Dictionary:
	return Content.rules("tips")["tips"]

## A tip's line with your Boki's name and your keys filled in.
static func text(id: String) -> String:
	var line := String(lines().get(id, ""))
	line = line.replace("{boki}", String(Save.active_kin().get("name", "your Boki")))
	for found in RegEx.create_from_string("\\{(\\w+)\\}").search_all(line):
		line = line.replace(found.get_string(), Settings.key_cap(found.get_string(1)))
	return line

## The tips this save has seen, oldest first.
static func seen() -> Array:
	return Save.d.get("tips", [])

## Shows tip `id` if this save hasn't seen it, and logs it.
func show(id: String) -> void:
	if not _allowed() or seen().has(id):
		return
	Save.d["tips"] = seen() + [id]
	m.hud.tip(text(id))

## Something that can't work (a locked chest, no key): one short card, the latest replacing the last.
func remind(id: String) -> void:
	remind_text = String(Content.rules("tips")["reminders"][id])
	remind_t = float(Content.rules("tips")["remind_s"])

func tick(dt: float) -> void:
	remind_t = maxf(0.0, remind_t - dt)
	var p := m.player
	if not _allowed() or p.dropping:
		return
	var k: Kin = p.kin
	if k and p.ult >= 1.0 and KinMerge.def_for(k) and (p.ak == null or int(p.slot_lv.get("ult", 0)) > 0):
		show("ult")
	if k and k.state == "active":
		show("skill")
	if not m.interact.is_empty() and m.interact["kind"] == "catch":
		show("catch")
	if m.exits and not m.interact.is_empty() and m.interact["kind"] == "exit":
		match String(m.interact["x"]["kind"]):
			"dock": show("exit_dock")
			"hatch": show("exit_hatch")
	if p.downed:
		show("down")

## Tips are for real expeditions with tips on: not the Trial, the Arena, a bot run or a recording.
func _allowed() -> bool:
	var p := m.player
	if p == null or p.out or p.riding or m.hud == null or not Settings.get_v("tips") or Record.clean():
		return false
	return not (m.opts.get("tutorial", false) or m.opts.get("arena", false) or m.opts.get("autoplay", false))

## Save migration, keyed by its own field: an old save kept seen tips as flags in "tutorial"; they
## move into the "tips" log (old saves load as before, and see no tip twice).
static func migrate(data: Dictionary) -> void:
	if data.has("tips"):
		return
	var flags: Dictionary = data.get("tutorial", {}) if typeof(data.get("tutorial")) == TYPE_DICTIONARY else {}
	var seen_ids: Array = []
	for id in lines():
		if bool(flags.get(id, false)):
			seen_ids.append(id)
		flags.erase(id)
	for id in TAUGHT:
		flags.erase(id)
	data["tips"] = seen_ids
