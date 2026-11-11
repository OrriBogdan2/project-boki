class_name SoloWords
extends RefCounted
## Solo runs (Solos mode, tutorial, arena: squad size 1) have no squad, so hints and tutorial text must not
## talk about one. `solo()` tells a match's opts apart; `leaks()` is the words list the --first-match-guide-check
## fails on. Text with a squad in it either has a solo version or is not shown in solos.

const WORDS := ["squad", "teammate"]   # lower case; "squadmate" contains "squad"

static func solo(opts: Dictionary) -> bool:
	return int(opts.get("squad", 1)) <= 1

## The first squad word the text uses, or "" for a clean text.
static func leaks(text: String) -> String:
	var low := text.to_lower()
	for w: String in WORDS:
		if low.contains(w):
			return w
	return ""
