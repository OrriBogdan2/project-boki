class_name FocusLoss
extends RefCounted
## Alt-tab (NOTIFICATION_APPLICATION_FOCUS_OUT): the window may never be told a key or button came up, so every
## held input is let go by hand. Settings calls release_input / restore_cursor for every scene (the farm, town and
## the menus read the same actions); Match calls drop_hunter for the buttons the Hunter holds. A hold is dropped the
## way a merge drops it (MergeAugment.drop_class_holds, ArchKit.drop_holds): no shot, no perfect release.

const HELD := ["fire", "sec_hold", "dash_down", "glide", "glide_btn", "crouch", "interact", "x_down"]

static var _cursor := Input.MOUSE_MODE_VISIBLE      # the mouse mode in effect when the window lost focus

## Every action up, and the cursor shown (the match hides it behind its own crosshair).
static func release_input() -> void:
	for a in InputMap.get_actions():
		Input.action_release(a)
	_cursor = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

static func restore_cursor() -> void:
	Input.mouse_mode = _cursor

## Is any button of this Hunter down, or a hold of its weapon or kit under way?
static func holding(h: Hunter) -> bool:
	for k in HELD:
		if bool(h.inp.get(k, false)):
			return true
	return h.draw_t >= 0.0 or h.mel_hold > 0.0 or (h.ak != null and h.ak.rmb_down)

## The Hunter stops walking and every button it holds is dropped with no effect; so are the presses still
## waiting and the aim of a held cast.
static func drop_hunter(m: Match) -> void:
	m.aim_hold = ""
	var h := m.player
	if h == null:
		return
	if holding(h):
		MergeAugment.drop_class_holds(h)
		if h.ak != null:
			h.ak.drop_holds()
	h.inp["move"] = Vector2.ZERO
	for k in h.inp:
		if h.inp[k] is bool:
			h.inp[k] = false       # held buttons, and a press that was waiting for the menu to close
	for k in m.pending_input:
		m.pending_input[k] = false
