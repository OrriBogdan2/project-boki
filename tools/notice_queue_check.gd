extends RefCounted
## --notice-queue-check: the match's one notice queue (NoticeQueue).
##   1. priority: a stolen Boki / you down beats match calls, then squad events, region names, pickups
##   2. one banner at a time, however many are pushed, and a repeat merges into it
##   3. a higher notice cuts a lower banner short (after its MIN_SHOW); a stale low one is dropped
##   4. a region name with a short form shows it when others wait; a hold keeps everything back
##   5. the band stays inside the safe area and out of the reticle zone, 720p to ultrawide,
##      with the ally alerts up too, and a long line wraps inside it
## Never touches the save.

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3440, 1440), Vector2(5120, 1440)]
const LONG := "Thief took Ember! Chase them down: they're marked, and you're faster heading their way, so run"

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("NOTICEQ %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(host)
	_priority(host)
	_one_at_a_time(host)
	_cut_and_stale(host)
	_short_and_hold(host)
	_band(host)
	host.queue_free()
	print("NOTICEQ DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _fresh(host: Control) -> NoticeQueue:
	var q := NoticeQueue.new()
	host.add_child(q)
	return q

## Steps the queue `secs` seconds; returns the banners that came on show, in order.
func _run(q: NoticeQueue, secs: float, seen: Array[String]) -> void:
	for i in int(secs / 0.1):
		q._process(0.1)
		for t in q.texts():
			if seen.is_empty() or seen.back() != t:
				seen.append(t)

# ------------------------------------------------------------------ 1. priority
func _priority(host: Control) -> void:
	var q := _fresh(host)
	q.hold = true
	q.push("pickup", Color.WHITE, NoticeQueue.PICKUP)
	q.push("squad", Color.WHITE, NoticeQueue.SQUAD)
	q.push("critical", Color.WHITE, NoticeQueue.CRITICAL)
	q.push("region", Color.WHITE, NoticeQueue.REGION)
	q.push("call", Color.WHITE, NoticeQueue.CALL)
	q.hold = false
	var seen: Array[String] = []
	_run(q, 9.0, seen)
	ok(seen == ["critical", "call", "squad"], "stolen or down first, then calls, then squad events (%s)" % str(seen))
	_run(q, 6.0, seen)
	ok(q.waiting() == 0 and not seen.has("region") and not seen.has("pickup"),
		"region names and pickups that waited too long are gone")
	q.clear()
	q.hold = true
	q.push("pickup", Color.WHITE, NoticeQueue.PICKUP)
	q.push("region", Color.WHITE, NoticeQueue.REGION)
	q.hold = false
	ok(q.texts() == ["region"], "a region name goes before a pickup")
	q.queue_free()

# ------------------------------------------------------------------ 2. one at a time
func _one_at_a_time(host: Control) -> void:
	var q := _fresh(host)
	var many := true
	for i in 200:
		if i % 7 == 0:
			q.push("note %d" % i, Color.WHITE, i % 5)
		q._process(0.1)
		many = many and q.texts().size() <= 1 and q.rects().size() <= 1
	ok(many, "never more than one banner on screen over 20 s of mixed notices")
	q.clear()
	q.push("Ember", Color.ORANGE)
	q.push("Ember", Color.ORANGE)
	ok(q.texts() == ["Ember  x2"] and q.count() == 1, "a repeat merges into the banner: %s" % str(q.texts()))
	q.queue_free()

# ------------------------------------------------------------------ 3. cut short, stale
func _cut_and_stale(host: Control) -> void:
	var q := _fresh(host)
	q.push("pickup", Color.WHITE, NoticeQueue.PICKUP)
	q.push("call", Color.WHITE, NoticeQueue.CALL)
	q._process(NoticeQueue.MIN_SHOW * 0.5)
	ok(q.texts() == ["pickup"], "a banner keeps its first moment even against a higher one")
	var seen: Array[String] = ["pickup"]
	_run(q, NoticeQueue.MIN_SHOW + NoticeQueue.FADE_OUT + 0.3, seen)
	ok(seen == ["pickup", "call"], "then the higher one cuts it short (%s)" % str(seen))
	q.clear()
	q.hold = true
	q.push("critical", Color.WHITE, NoticeQueue.CRITICAL)
	q.push("old pickup", Color.WHITE, NoticeQueue.PICKUP)
	q.push("old region", Color.WHITE, NoticeQueue.REGION)
	q._process(float(NoticeQueue.STALE[NoticeQueue.PICKUP]) + 0.1)
	ok(q.waiting() == 2, "a pickup waiting past its STALE is dropped, the others stay (%d wait)" % q.waiting())
	q._process(float(NoticeQueue.STALE[NoticeQueue.REGION]))
	ok(q.waiting() == 1, "a region name goes stale later, a critical one never (%d wait)" % q.waiting())
	q.queue_free()

# ------------------------------------------------------------------ 4. short form, hold
func _short_and_hold(host: Control) -> void:
	var q := _fresh(host)
	q.push("squad", Color.WHITE, NoticeQueue.SQUAD)
	q.push("Bramble Isle  ·  thick woods, few monsters", Color.GREEN, NoticeQueue.REGION, "Bramble Isle")
	q.push("a first-time hint", Color.WHITE, NoticeQueue.REGION)
	var seen: Array[String] = []
	_run(q, 6.0, seen)
	ok(seen.has("Bramble Isle") and not seen.has("Bramble Isle  ·  thick woods, few monsters"),
		"a region name shows short while others wait (%s)" % str(seen))
	q.clear()
	q.push("Bramble Isle  ·  thick woods, few monsters", Color.GREEN, NoticeQueue.REGION, "Bramble Isle")
	ok(q.texts() == ["Bramble Isle  ·  thick woods, few monsters"], "and in full when it is alone")
	q.clear()
	q.hold = true
	q.push("held", Color.WHITE, NoticeQueue.CRITICAL)
	q._process(0.5)
	ok(q.texts().is_empty() and q.waiting() == 1, "held: nothing shows")
	q.hold = false
	ok(q.texts() == ["held"], "the hold lifts: it shows at once")
	q.queue_free()

# ------------------------------------------------------------------ 5. the band
func _band(host: Control) -> void:
	for sz: Vector2 in SIZES:
		var zone := NoticeQueue.reticle_zone(sz)
		var safe := Rect2(sz * NoticeQueue.SAFE, sz * (1.0 - 2.0 * NoticeQueue.SAFE))
		var all_ok := true
		var q := _fresh(host)
		for top in [0.0, 84.0, 84.0 + 3 * 78.0, sz.y]:
			q.band = NoticeQueue.band_for(sz, top)
			q.push(LONG, Color.WHITE, NoticeQueue.CALL)
			q._process(0.5)
			var r: Rect2 = q.rects()[0]
			var in_safe := safe.encloses(r) and safe.encloses(q.band)
			var off_zone := not r.intersects(zone) and not q.band.intersects(zone)
			if not in_safe or not off_zone or r.end.y > q.band.end.y + 0.5:
				all_ok = false
				print("NOTICEQ   bad at %s top %.0f: banner %s band %s zone %s" % [sz, top, r, q.band, zone])
			q.clear()
		ok(all_ok, "%dx%d: the banner stays in the safe area, off the reticle zone, two lines at most" % [sz.x, sz.y])
		q.queue_free()
