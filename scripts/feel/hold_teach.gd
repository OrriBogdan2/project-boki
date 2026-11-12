class_name HoldTeach
extends RefCounted
## Teaches that chopping (F), mining (F), gliding (Space) and every "Hold F" prompt are HOLD actions.
## A quick press-and-let-go (a tap) on one of them answers at once: the ring around the key flashes
## part-full and drains, a small "Hold" pops up and a soft click plays. After HINT_AFTER taps in a
## session one line says how ("Hold F to chop"), once per action per session. Once the player has
## finished the hold DONE_N times (kept in Settings "hold_done", so it lasts across saves and runs)
## that action stops teaching: no pop, click or hint, just the ring.
## Callers feed it the key state each frame: key() for taps, done() once a hold went through.
## The ring itself is HoldPrompt (scripts/ui/hold_prompt.gd); docs/HUD.md "Hold prompts".

const TAP_S := 0.25  # s: a press let go sooner than this is a tap, not a hold
const HINT_AFTER := 2  # taps in a session before the one-line hint
const DONE_N := 3  # finished holds before an action stops teaching for good
const FLASH_S := 0.5  # s the ring flash lasts (full on the tap frame itself, then drains)
const FLASH_FILL := 0.35  # how far a tap's flash fills the ring (0..1)
const POP_S := 0.8  # s the "Hold" pop rises and fades
const CLICK_DB := -10.0  # the tap click sits under the game's sounds
const GLIDE_DONE_S := 0.6  # s with the glider open and Space still down: a finished glide hold
const HOLD_DONE_S := 1.0  # s of F held on a chop, a mine or a "Hold F" prompt: a finished hold
const HINTS := {
	"chop": "Hold %s to chop",
	"mine": "Hold %s to mine",
	"glide": "Hold %s to glide",
	"hold": "Hold %s until the ring fills",
}
const KEYS := {"chop": "interact", "mine": "interact", "hold": "interact", "glide": "jump"}
const SETTING := "hold_done"

## Checks set this to step time by hand; below zero the real clock runs.
static var clock := -1.0
## action -> {was, down_t, taps, hinted, flash_t, pop_t, done, kicks}; this session only.
static var _st := {}


static func now() -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() * 0.001


static func reset_session() -> void:
	_st.clear()


static func _s(action: String) -> Dictionary:
	if not _st.has(action):
		_st[action] = {
			"was": false,
			"down_t": -1.0,
			"taps": 0,
			"hinted": false,
			"flash_t": -9.0,
			"pop_t": -9.0,
			"done": false,
			"kicks": 0
		}
	return _st[action]


## The key as the player reads it: "F", "Space" (not "SPACE").
static func key_text(action: String) -> String:
	var k := Settings.key_cap(String(KEYS.get(action, "interact")))
	return k if k.length() <= 2 else k.capitalize()


static func hint(action: String) -> String:
	return String(HINTS.get(action, HINTS["hold"])) % key_text(action)


## Feed the key every frame. ok_press: a press counts here (at a tree, in the air); ok_release: the
## let-go still counts (not landed, no wall kick). say(text) shows the hint line. True on a tap.
static func key(action: String, down: bool, ok_press: bool, ok_release: bool, say: Callable) -> bool:
	var s := _s(action)
	var t := now()
	var was: bool = s["was"]
	s["was"] = down
	if down and not was:
		s["down_t"] = t if ok_press else -1.0
		s["done"] = false
		return false
	if was and not down:
		var start: float = s["down_t"]
		s["down_t"] = -1.0
		if start >= 0.0 and t - start < TAP_S and ok_release:
			_tap(action, s, say)
			return true
	return false


static func _tap(action: String, s: Dictionary, say: Callable) -> void:
	var t := now()
	s["flash_t"] = t
	s["taps"] = int(s["taps"]) + 1
	if taught(action):
		return
	s["pop_t"] = t
	Sfx.play("click", null, CLICK_DB)
	if int(s["taps"]) >= HINT_AFTER and not s["hinted"]:
		s["hinted"] = true
		say.call(hint(action))


## Seconds the current press has been down (0 when up or the press didn't count).
static func held_for(action: String) -> float:
	var s := _s(action)
	return now() - float(s["down_t"]) if s["was"] and float(s["down_t"]) >= 0.0 else 0.0


## The hold went through: counts once per press, saved, capped at DONE_N.
static func done(action: String) -> void:
	var s := _s(action)
	if s["done"]:
		return
	s["done"] = true
	var d: Dictionary = (Settings.get_v(SETTING) as Dictionary).duplicate()
	var n := int(d.get(action, 0))
	if n >= DONE_N:
		return
	d[action] = n + 1
	Settings.set_v(SETTING, d)


## Has the player finished this hold n times (ever)?
static func count(action: String) -> int:
	return int((Settings.get_v(SETTING) as Dictionary).get(action, 0))


static func taught(action: String) -> bool:
	return count(action) >= DONE_N


static func taps(action: String) -> int:
	return int(_s(action)["taps"])


static func hinted(action: String) -> bool:
	return bool(_s(action)["hinted"])


## How full a tap's flash holds the ring right now (0 when none).
static func flash(action: String) -> float:
	var e := (now() - float(_s(action)["flash_t"])) / FLASH_S
	if e < 0.0 or e > 1.0:
		return 0.0
	return FLASH_FILL * (1.0 - e)


## 0..1 through the "Hold" pop, or -1 when none is showing.
static func pop(action: String) -> float:
	var e := (now() - float(_s(action)["pop_t"])) / POP_S
	return e if e >= 0.0 and e <= 1.0 else -1.0


## Is any feedback (flash or pop) showing for this action?
static func showing(action: String) -> bool:
	return flash(action) > 0.0 or pop(action) >= 0.0


## The match, every frame (match.gd _tips): Space in the air for the glider, F on any "Hold F" prompt.
static func match_tick(m) -> void:
	var p: Hunter = m.player
	if p == null or p.out:
		return
	var say := func(t: String) -> void: _tip(m, t)
	# glide: a press that starts in the air (not the jump itself, not a wall kick) and ends quickly
	var space: bool = Input.is_action_pressed("jump") and not m.paused
	var air: bool = not p.grounded and not p.downed and p.jump_at != m.time
	var kicks := int(p.stats.get("wall_kicks", 0))
	var g := _s("glide")
	if space and not g["was"]:
		g["kicks"] = kicks
	key("glide", space, air, not p.grounded and kicks == int(g["kicks"]), say)
	if p.gliding and held_for("glide") >= GLIDE_DONE_S:
		done("glide")
	# any "Hold F ..." prompt (chest, uplink, rune, scan, revive, stomp ...)
	var it: Dictionary = m.interact
	var at_hold := not it.is_empty() and HoldPrompt.is_hold(String(it.get("label", "")))
	var f: bool = Input.is_action_pressed("interact") and not m.paused
	key("hold", f, at_hold, true, say)
	if held_for("hold") >= HOLD_DONE_S:
		done("hold")


static func _tip(m, t: String) -> void:
	if m.hud:
		m.hud.tip(t)


## Home, every frame (HomeGather.tick). `what`: the "tree"/"rock" you can work now, "" for none.
static func home_tick(h, what: String, working: bool) -> void:
	var action := "mine" if what == "rock" else "chop"
	key(action, h.tw.held(), what != "", true, func(t: String): h._toast(t))
	if working and held_for(action) >= HOLD_DONE_S:
		done(action)
