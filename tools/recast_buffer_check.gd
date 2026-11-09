extends "res://tools/hero_pair_check.gd"
## --recast-buffer-check: the owner's recast rule (DECISIONS 2026-11-08, RecastBuffer). A press 0.1s before a
## recast window opens fires on the open, one 0.2s early does not, and a window that closes unused raises the
## EXPIRED flag once (E and the hero ultimate). Uses a stub kit so the window opens exactly when the check says.

class StubKit extends ArchKit:
	var live := false           # the stub's window (E and X)
	var taken := 0              # recasts that went through
	func e_recastable() -> bool: return live
	func e_recast() -> bool:
		taken += 1
		live = false
		e_t = 0.0
		return true
	func ult_running() -> bool: return live
	func ult_recastable() -> bool: return live
	func ult_recast() -> bool:
		taken += 1
		live = false
		return true

func run(main_node: Node) -> void:
	main = main_node
	var r := setup("ashwick", 6.0)
	var K := StubKit.new()
	K.h = r[1]
	K.m = r[0]
	K.id = "ashwick"
	K.d = Arch.def("ashwick")
	K.rb = RecastBuffer.new(K)
	K.flow = DashFlow.new(K)
	var buf := float(Content.rules("tuning")["recast_buffer_s"])
	var flash_s := float(Content.rules("tuning")["recast_expired_s"])
	var tuned := is_equal_approx(buf, 0.15) and is_equal_approx(flash_s, 0.6)
	ok("the buffer is 0.15s, the flash 0.6s, from content/rules/tuning.json", tuned)
	for slot in ["k1", "x"]:
		_slot(K, slot)
	print("PAIRCHECK recast-buffer DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Presses `ahead` s before the window opens; true when the recast went through.
func _press_then_open(K: StubKit, slot: String, ahead: float) -> bool:
	K.taken = 0
	K.live = false
	K.e_t = 0.0
	K.cd = {"rmb": 0.0, "e": 9.0, "r": 0.0, "x": 9.0}
	K.rb.held.clear()
	_press(K, slot)
	_run(K, ahead)
	K.live = true
	K.e_t = 5.0
	_run(K, 0.05)
	return K.taken == 1

func _press(K: StubKit, slot: String) -> void:
	if slot == "k1":
		K.use_e()
	else:
		HeroUlt.press(K, func(): return false)

func _run(K: StubKit, secs: float) -> void:
	var t := 0.0
	while t < secs - 0.001:
		K.tick(DT)
		t += DT

func _slot(K: StubKit, slot: String) -> void:
	ok("%s: a press 0.1s early fires when the window opens" % slot, _press_then_open(K, slot, 0.1))
	ok("%s: a press 0.2s early does not" % slot, not _press_then_open(K, slot, 0.2))
	_press_then_open(K, slot, 0.0)
	K.live = false
	K.cd = {"rmb": 0.0, "e": 9.0, "r": 0.0, "x": 9.0}
	_press(K, slot)
	K.rb.cast(slot)
	ok("%s: a fresh cast drops the press kept from before it" % slot, not K.rb.held.has(slot))
	# expiry: a window that runs out unused raises the flag once and it clears on its own
	K.live = true
	K.e_t = 0.1
	K.rb.expired.clear()
	K.rb.x_open = false
	K.rb.x_taken = false
	_run(K, 0.05)
	K.live = true
	K.e_t = 0.1
	_run(K, 0.2 if slot == "k1" else 0.05)
	if slot == "x":
		K.live = false
		_run(K, 0.05)
	var flash := float(K.rb.expired.get(slot, 0.0))
	ok("%s: a window that closes unused raises EXPIRED" % slot, flash > 0.0)
	_run(K, 0.3)
	ok("%s: it is raised once (it only counts down)" % slot, float(K.rb.expired.get(slot, 0.0)) < flash - 0.2)
	_run(K, 0.5)
	ok("%s: and clears after 0.6s" % slot, not K.rb.expired.has(slot))
	# a window that was used does not flash
	K.rb.expired.clear()
	K.live = true
	K.e_t = 5.0
	_run(K, 0.05)
	_press(K, slot)
	_run(K, 0.1)
	ok("%s: a used window does not flash" % slot, not K.rb.expired.has(slot))
