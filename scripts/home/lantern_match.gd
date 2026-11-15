class_name LanternMatch
extends RefCounted
## Lantern Match (briefs/design/GARDEN_MODERN.md section 4.2 game 6), a memory game; only with farm_build.json
## base_mode on. Hushwood is not on this base, so its glowcap ring stands by the Training post. Twelve
## glowcaps flash in pairs, then go dark; open two at a time to find the pairs. Your Boki sniffs every few
## seconds (sooner with Focus, sooner still if curious) and points at the partner of the last cap you opened,
## if it saw that cap. Solo against the clock (a cleared ring deals a new one; reach solo_goal pairs), or
## turn by turn against the next rested Boki.
## Prizes and the cup go through GardenPrizes ("lantern"); a solo win rolls the table but never moves the cup.
## Tuning: content/rules/lantern_match.json. The game itself (Board) has no nodes, so --lantern-check runs it.
##
## The flow is one explicit state machine (briefs/STATE_MACHINES.md): only go() writes `state`.
##   IDLE   -> PLAY    a mode picked on the ring's panel: the ring flashes, then the clock runs
##   PLAY   -> RESULT  the clock runs out (versus: or the ring is cleared): the result card shows
##          -> IDLE    the panel is closed (Close or the menu key): the game is called off
##   RESULT -> IDLE    the card's time is up

enum S { IDLE, PLAY, RESULT }
const TABLE := {S.IDLE: [S.PLAY], S.PLAY: [S.RESULT, S.IDLE], S.RESULT: [S.IDLE]}

const GAME := "lantern"                      # the game's id in garden_prizes.json
const PANEL := "Lantern Match"               # the panel's title (home panel_open while playing)
const RING_OFF := Vector3(-2.8, 0, 2.9)      # m from the Training post to the glowcap ring's middle
const RING_R := 0.7                          # m, the prop ring's radius
const REACH := 1.4                           # m from the ring's middle to use it
const CAP_R := 0.11                          # m, a prop glowcap's radius
const UI_RING := 150.0                       # px, the panel ring's radius
const UI_CAP := 54.0                         # px, a panel cap button's size
const DARK := Color("2a2340")                # a closed cap on the panel

static func rules() -> Dictionary:
	return Content.rules("lantern_match")

static func _stat(rec: Dictionary, s: String) -> float:
	return float(rec.get("stats", {}).get(s, 0))

## Seconds between a Boki's sniffs: from Focus and curiosity.
static func sniff_every(rec: Dictionary) -> float:
	var R := rules()
	var rate := 1.0 + _stat(rec, "focus") * float(R["sniff_per_focus"])
	rate *= 1.0 + (float(rec.get("traits", {}).get("curiosity", 0.5)) - 0.5) * float(R["sniff_curiosity"])
	return maxf(float(R["sniff_s"]) / rate, float(R["sniff_min"]))

## The chance your Boki notices a pair while it flashes.
static func see_p(rec: Dictionary) -> float:
	var R := rules()
	return minf(float(R["see"]) + _stat(rec, "focus") * float(R["see_per_focus"]), 1.0)

## The chance the rival Boki remembers a cap it has seen.
static func mem_p(rec: Dictionary) -> float:
	var R := rules()
	return minf(float(R["foe_mem"]) + _stat(rec, "focus") * float(R["foe_mem_per_focus"]), 0.95)

## One game on the ring: caps 0..11 round the ring, each holding a pair id.
class Board:
	var R: Dictionary
	var rng: RandomNumberGenerator
	var mine: Dictionary            # your Boki: it sniffs and points
	var foe: Dictionary             # the rival Boki in versus, empty solo
	var caps: Array = []            # pair id of each cap
	var matched: Array = []         # each cap's pair is found
	var saw: Array = []             # your Boki has seen this cap's colour
	var mem: Array = []             # the rival remembers this cap's colour
	var open: Array = []            # caps lit right now (at most two)
	var pairs: Array = [0, 0]       # pairs found: you, the rival
	var turn := 0                   # 0 you, 1 the rival
	var t := 0.0                    # s on the clock (it waits while a ring flashes)
	var flash_t := 0.0              # s of the ring's flash left
	var shut_t := 0.0               # s until a mismatch goes dark
	var last := -1                  # the last cap you opened
	var hint := -1                  # the cap your Boki points at, -1 for none
	var hints := 0                  # times it pointed
	var sniff_t := 0.0              # s until its next sniff
	var foe_t := 0.0                # s until the rival opens its next cap
	var ver := 0                    # bumped on every change the panel shows

	func _init(me: Dictionary, rival: Dictionary, r: RandomNumberGenerator) -> void:
		R = LanternMatch.rules()
		rng = r
		mine = me
		foe = rival
		sniff_t = LanternMatch.sniff_every(mine)
		foe_t = float(R["foe_s"])
		_deal()

	## A fresh ring: shuffled with the board's own dice, then it flashes. Who saw which pair is rolled here.
	func _deal() -> void:
		var n: int = (R["colours"] as Array).size()
		caps.clear()
		for i in n * 2:
			caps.append(i % n)
		for i in range(caps.size() - 1, 0, -1):      # Fisher-Yates
			var j := rng.randi_range(0, i)
			var c: int = caps[i]
			caps[i] = caps[j]
			caps[j] = c
		matched.resize(caps.size())
		matched.fill(false)
		saw.resize(caps.size())
		mem.resize(caps.size())
		var sp := LanternMatch.see_p(mine)
		for pair in n:
			var seen := rng.randf() < sp
			for i in caps.size():
				if caps[i] == pair:
					saw[i] = seen
					mem[i] = versus() and rng.randf() < LanternMatch.mem_p(foe)
		last = -1
		hint = -1
		flash_t = float(R["flash_s"]) * n
		ver += 1

	func versus() -> bool:
		return not foe.is_empty()

	## The pair glowing in the flash, -1 once it is over.
	func flashing() -> int:
		return (R["colours"] as Array).size() - 1 - int(flash_t / float(R["flash_s"])) if flash_t > 0.0 else -1

	func lit(i: int) -> bool:
		return matched[i] or open.has(i) or caps[i] == flashing()

	func partner(i: int) -> int:
		for j in caps.size():
			if j != i and caps[j] == caps[i]:
				return j
		return -1

	## The clock ran out, or (versus) the ring is cleared. A cleared solo ring deals a new one.
	func over() -> bool:
		return t >= float(R["time_s"]) or (versus() and not matched.has(false))

	## True when you won: solo, solo_goal pairs before the clock; versus, more pairs than the rival.
	func won() -> bool:
		return pairs[0] > pairs[1] if versus() else pairs[0] >= int(R["solo_goal"])

	func can_open(i: int) -> bool:
		if flash_t > 0.0 or shut_t > 0.0 or over():
			return false
		return open.size() < 2 and not matched[i] and not open.has(i)

	## You open cap i on your turn; false when it cannot be opened now.
	func pick(i: int) -> bool:
		if turn != 0 or not can_open(i):
			return false
		last = i
		hint = -1
		_open(i)
		return true

	func _open(i: int) -> void:
		open.append(i)
		saw[i] = true
		if versus() and rng.randf() < LanternMatch.mem_p(foe):
			mem[i] = true
		ver += 1
		if open.size() < 2:
			return
		if caps[open[0]] == caps[open[1]]:
			for c in open:
				matched[c] = true
			pairs[turn] += 1
			open.clear()                              # a match keeps the turn
			if not versus() and not matched.has(false):
				_deal()
		else:
			shut_t = float(R["reveal_s"])

	func step(dt: float) -> void:
		if flash_t > 0.0:
			var was := flashing()
			flash_t -= dt
			if flashing() != was:
				ver += 1
			return
		if over():
			return
		t += dt
		if shut_t > 0.0:
			shut_t -= dt
			if shut_t <= 0.0:
				open.clear()
				if versus():
					turn = 1 - turn
					foe_t = float(R["foe_s"])
				ver += 1
			return
		if turn == 0:
			_sniff(dt)
		else:
			_foe(dt)

	func _sniff(dt: float) -> void:
		sniff_t -= dt
		if sniff_t > 0.0:
			return
		sniff_t = LanternMatch.sniff_every(mine)
		var to := partner(last) if last >= 0 else -1
		if to >= 0 and saw[to] and not matched[to] and not open.has(to):
			hint = to
			hints += 1
			ver += 1

	func _foe(dt: float) -> void:
		foe_t -= dt
		if foe_t > 0.0:
			return
		foe_t = float(R["foe_s"])
		_open(_foe_pick())

	## The rival's next cap: the partner of its lit cap or a remembered pair, else an unknown cap.
	func _foe_pick() -> int:
		var unknown: Array = []
		for i in caps.size():
			if matched[i] or open.has(i):
				continue
			var j := partner(i)
			if mem[i] and (open.has(j) or (open.is_empty() and mem[j])):
				return i
			if not mem[i]:
				unknown.append(i)
		if unknown.is_empty():
			for i in caps.size():
				if not matched[i] and not open.has(i):
					unknown.append(i)
		return unknown[rng.randi_range(0, unknown.size() - 1)]

## Pays out a finished game: energy, joy, trust, memories, gems, the prize roll and the cup.
static func settle(b: Board) -> Dictionary:
	var R := rules()
	var won := b.won()
	var draw: bool = b.versus() and b.pairs[0] == b.pairs[1]
	for rec in [b.mine, b.foe]:
		if not rec.is_empty():
			Care.change(rec, "energy", -float(R["energy"]))
	var rival := String(b.foe["name"]) if b.versus() else "the clock"
	if won:
		Care.change(b.mine, "joy", float(R["win_joy"]))
		Save.remember(b.mine, "lantern", "found the glowcap pairs before %s" % rival, float(R["win_trust"]))
	elif not draw:
		Care.change(b.mine, "joy", float(R["lose_joy"]))
		Save.remember(b.mine, "lantern", "lost Lantern Match to %s" % rival)
	Save.d["gems"] = int(Save.d["gems"]) + int(R["gems"])
	var prize := GardenPrizes.settle(GAME, b.mine, b.foe if b.versus() else {"stats": {}}, won)
	return {"won": won, "draw": draw, "pairs": b.pairs.duplicate(), "gems": int(R["gems"]), "prize": prize}

# ------------------------------------------------------------------ on the base
var h                          # the Home screen
var state := S.IDLE
var refused := 0               # moves the TABLE turned down
var state_t := 0.0             # s in the state
var ring: Node3D = null
var board: Board = null
var players: Array = []        # the home's kin entries in the game: you, then the rival in versus
var buttons: Array = []        # the panel's cap buttons, by cap
var head: Label = null         # the panel's clock and score line
var note: Label = null         # the panel's sniff and turn line
var shown_ver := -1
var shown_s := -1
var card: Control = null

func _init(home) -> void:
	h = home

## The only writer of `state`: false (and counted) when the TABLE lacks the move.
func go(to: S) -> bool:
	if not TABLE[state].has(to):
		refused += 1
		return false
	state = to
	state_t = 0.0
	return true

## The glowcap ring by the Training post (none without one); called when fixtures move.
func place() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
	ring = null
	if h.YARD_AT.x < -100.0:
		return
	ring = Node3D.new()
	ring.name = "GlowcapRing"
	ring.position = h.YARD_AT + RING_OFF
	h.add_child(ring)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.03
	stem.bottom_radius = 0.04
	stem.height = 0.16
	var cap := SphereMesh.new()
	cap.radius = CAP_R
	cap.height = CAP_R
	cap.is_hemisphere = true
	var stem_mat := BaseRace.mat(Color("e8dcc4"))
	var cols: Array = rules()["colours"]
	for i in cols.size() * 2:
		var at := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / (cols.size() * 2.0)) * RING_R
		var s := MeshInstance3D.new()
		s.mesh = stem
		s.material_override = stem_mat
		s.position = at + Vector3(0, 0.08, 0)
		ring.add_child(s)
		var c := MeshInstance3D.new()
		c.mesh = cap
		var m := BaseRace.mat(Color(String(cols[i % cols.size()])))
		m.emission_enabled = true
		m.emission = m.albedo_color
		c.material_override = m
		c.position = at + Vector3(0, 0.16, 0)
		ring.add_child(c)

func find(p2: Vector2) -> Dictionary:
	if state == S.IDLE and is_instance_valid(ring) \
			and p2.distance_to(Vector2(ring.position.x, ring.position.z)) <= REACH:
		return {"kind": "lantern"}
	return {}

func label() -> String:
	return "Play Lantern Match with %s" % Save.active_kin().get("name", "your partner")

## Opens the ring's panel: pick solo or versus.
func use() -> void:
	var ks: Array = h.hrace.entrants()
	if ks.is_empty():
		h._toast("Lantern Match needs a rested Boki out on the base")
		return
	var v: VBoxContainer = h._new_panel(PANEL, 520.0)
	v.add_child(UI.para("Twelve glowcaps flash in pairs, then go dark. Open two at a time to find the pairs. "
			+ "%s sniffs now and then and points at the partner of the cap you opened last." % ks[0]["rec"]["name"]))
	v.add_child(UI.primary("Solo against the clock", func(): _start([ks[0]])))
	if ks.size() > 1:
		v.add_child(UI.button("Turn by turn against %s" % ks[1]["rec"]["name"], func(): _start(ks.slice(0, 2))))

func _start(ks: Array) -> void:
	if not go(S.PLAY):
		return
	players = ks
	for k in players:
		k["busy"] = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	board = Board.new(ks[0]["rec"], ks[1]["rec"] if ks.size() > 1 else {}, rng)
	_board_panel()
	Sfx.play("whoosh", null, -8.0)

func _board_panel() -> void:
	var v: VBoxContainer = h._new_panel(PANEL, 520.0)
	head = UI.label("", 16, UI.INK)
	note = UI.para("Watch the caps glow...")
	v.add_child(head)
	v.add_child(note)
	var ring_ui := Control.new()
	ring_ui.custom_minimum_size = Vector2.ONE * (UI_RING * 2.0 + UI_CAP)
	v.add_child(ring_ui)
	buttons.clear()
	for i in board.caps.size():
		var b := Button.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(UI_CAP * 0.5))
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.custom_minimum_size = Vector2.ONE * UI_CAP
		b.size = b.custom_minimum_size
		var ang := TAU * i / board.caps.size()
		b.position = Vector2.ONE * UI_RING + Vector2(sin(ang), -cos(ang)) * UI_RING
		b.pressed.connect(_pick.bind(i))
		ring_ui.add_child(b)
		buttons.append(b)
	shown_ver = -1

func _pick(i: int) -> void:
	if board != null and board.pick(i):
		Sfx.play("click", null, -10.0)

func tick(d: float) -> void:
	state_t += d
	match state:
		S.PLAY:
			if h.panel_open != PANEL:
				_end(false)
				return
			board.step(d)
			_show()
			if board.over():
				_end(true)
		S.RESULT:
			if state_t >= float(rules()["card_s"]):
				if is_instance_valid(card):
					card.queue_free()
				go(S.IDLE)

## Repaints the panel when the board changed or the clock ticked a second.
func _show() -> void:
	var secs := ceili(float(rules()["time_s"]) - board.t)
	if board.ver == shown_ver and secs == shown_s:
		return
	shown_ver = board.ver
	shown_s = secs
	var cols: Array = rules()["colours"]
	var score := "Pairs %d" % board.pairs[0]
	if board.versus():
		score += "  ·  %s %d" % [board.foe["name"], board.pairs[1]]
	head.text = "%d s  ·  %s" % [secs, score]
	for i in buttons.size():
		var sb: StyleBoxFlat = buttons[i].get_theme_stylebox("normal")
		sb.bg_color = Color(String(cols[board.caps[i]])) if board.lit(i) else DARK
		sb.border_color = UI.GOLD
		sb.set_border_width_all(4 if i == board.hint else 0)
		buttons[i].disabled = board.matched[i]
	if board.flash_t > 0.0:
		note.text = "Watch the caps glow..."
	elif board.turn == 1:
		note.text = "%s's turn" % board.foe["name"]
	elif board.hint >= 0:
		note.text = "%s sniffs... and points at the gold-ringed cap!" % board.mine["name"]
	else:
		note.text = "Your turn: open two caps"

func _end(finished: bool) -> void:
	var res := settle(board) if finished else {}
	for k in players:
		k["busy"] = false
		k["t"] = 1.5
	if finished:
		h._close_panel()
		go(S.RESULT)
		_card(res)
		h._emote(players[0], "♥" if res["won"] else "…", true)
		Save.save_game()
	else:
		go(S.IDLE)
	board = null
	players = []
	buttons.clear()

func _card(res: Dictionary) -> void:
	if is_instance_valid(card):
		card.queue_free()
	var title := "The glowcaps win this time"
	if res["won"]:
		title = "The ring is lit: you win!"
	elif res["draw"]:
		title = "A draw!"
	var line := "Pairs: you %d" % res["pairs"][0]
	if board.versus():
		line += ", %s %d" % [board.foe["name"], res["pairs"][1]]
	card = BaseRace.result_card(h, [[title, 18, UI.ACCENT_HI], [line, 14, UI.INK],
			["+%d gems" % res["gems"], 14, UI.GOLD]] + GardenPrizes.rows(res["prize"], 14))
