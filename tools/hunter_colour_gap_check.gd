extends RefCounted
## --hunter-colour-gap-check: every Hunter's abilities are drawn in that Hunter's own colour
## (DECISIONS 11-08), so no two Hunter colours (archetype "color") may sit closer than GAP in OKLab.
## Pairs the owner has not ruled on yet are listed in OPEN (docs/DEBT.md); a listed pair that has
## since cleared the bar fails too, so the list never goes stale.
## Prints "HCGCHECK ok|FAIL ..." lines and "HCGCHECK DONE, failures: N".

## Smallest OKLab distance (Euclidean, L in 0..1) between two Hunter colours. 0.02 is about the
## smallest step anyone sees; 0.15 keeps two effects apart at a glance mid-fight.
const GAP := 0.15
## Close pairs left for the owner to rule on (docs/DEBT.md "Hunter colours under the gap").
const OPEN := [["ostra", "tender"], ["ashwick", "juggernaut"], ["gunslinger", "tender"],
		["ostra", "rimewright"], ["bulwark", "dredge"], ["archer", "thief"], ["dolm", "thief"],
		["dredge", "gunslinger"], ["archer", "mage"]]

var bad := 0

func ok(cond: bool, msg: String) -> void:
	print("HCGCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1

## sRGB colour to OKLab (Ottosson 2020).
static func oklab(c: Color) -> Vector3:
	var lin := c.srgb_to_linear()
	var l := pow(0.4122214708 * lin.r + 0.5363325363 * lin.g + 0.0514459929 * lin.b, 1.0 / 3.0)
	var m := pow(0.2119034982 * lin.r + 0.6806995451 * lin.g + 0.1073969566 * lin.b, 1.0 / 3.0)
	var s := pow(0.0883024619 * lin.r + 0.2817188376 * lin.g + 0.6299787005 * lin.b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
			1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
			0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

func run(main: Node) -> void:
	var ids: Array = Arch.ORDER
	ok(ids.size() == 13, "13 Hunters to compare (%d)" % ids.size())
	ok(oklab(Color.WHITE).distance_to(Vector3(1, 0, 0)) < 0.001, "OKLab: white is L 1, no hue")
	var open_seen := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var gap := oklab(Arch.color(a)).distance_to(oklab(Arch.color(b)))
			var listed := OPEN.has([a, b]) or OPEN.has([b, a])
			if listed:
				open_seen += 1
				ok(gap < GAP, "%s / %s is still close (%.3f), keep it on the open list" % [a, b, gap])
			elif gap < GAP:
				ok(false, "%s / %s colours are %.3f apart in OKLab, under %.2f" % [a, b, gap, GAP])
	ok(open_seen == OPEN.size(), "every open pair names two Hunters (%d/%d)" % [open_seen, OPEN.size()])
	print("HCGCHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
