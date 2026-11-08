class_name KinVoice
## What a kin says in a match. Lines depend on its strongest trait and how much it trusts you.
## If the AI wrote personal lines for this kin before the match, those are used most of the time.

const BASE := {
	"throw": {
		"bravery": ["Charging in!", "Watch this!", "Out of my way!"],
		"loyalty": ["Got your back!", "On it, partner!", "I'll handle it!"],
		"temper": ["Finally!", "They're mine!", "Let me at 'em!"],
		"curiosity": ["Ooh, what's that?", "Wheee!", "New friend? No? Okay!"],
	},
	"refuse": {
		"bravery": ["Not THAT many. No.", "Pick a fight I can win!"],
		"loyalty": ["Please, not there. We'll both get hurt.", "I want to help, but not like this."],
		"temper": ["Nope. Throw yourself.", "You throw me there, you're on your own!"],
		"curiosity": ["Hmm. I counted too many teeth.", "That looks like a bad idea."],
	},
	"hesitate": {
		"bravery": ["...fine. Going!", "Ugh. Okay!"],
		"loyalty": ["If you say so...", "Okay... trusting you."],
		"temper": ["You owe me for this!", "Fine! FINE!"],
		"curiosity": ["Uh, is that safe? Going!", "Okay okay okay!"],
	},
	"ignore": {"_": ["One sec, almost got 'em!", "Not yet!", "Finishing this!"]},
	"scared": {
		"bravery": ["Falling back!", "Too hot, coming back!"],
		"loyalty": ["I'm hurt, coming to you!", "Need a breather!"],
		"temper": ["Ow! OW! Retreating!", "That one bites back!"],
		"curiosity": ["Owie. Back to the shoulder.", "I've seen enough!"],
	},
	"revive": {
		"bravery": ["Get up! I've got you!", "Hold on, I'm coming!"],
		"loyalty": ["I'm here! Stay with me!", "Don't you dare give up!"],
		"temper": ["Get UP! We're not done!", "Seriously? Up!"],
		"curiosity": ["Is lying down a strategy? Up!", "Coming! Coming!"],
	},
	"revive_low": {"_": ["...I'll think about it.", "You keep throwing me around. Hmm.", "Do I have to?"]},
	"callout": {"_": ["Hunter %s!", "Someone's coming %s!", "Movement %s!", "Rival %s, careful!"]},
	"wild": {"_": ["A wild %s! Can we make friends?", "I smell a %s nearby!", "Look, a %s!"]},
	"kill": {"_": ["Got one!", "Down they go!", "Too easy!", "Nice!"]},
	"owner_down": {"_": ["NO!", "Hang on!", "Get up!"]},
	"caught": {"_": ["A new friend!", "Welcome to the team!", "Another one for the farm!"]},
	"extract": {"_": ["We made it!", "Home time!", "What a run!"]},
}

## Teammate callouts and reactions (KinCompanion), by the side of it that shows in a fight.
## "_" is the fallback for any nature. %s is a direction ("to the north") or a name.
const CALL := {
	"behind": {"timid": ["Behind you! Behind you!", "Someone's sneaking up %s!"], "bold": ["Behind us! Turn, I'll hold them!", "Got one %s. Let's turn and fight!"],
		"_": ["Behind you!", "Watch your back, %s!", "Hunter behind us!"]},
	"hunter": {"timid": ["Hunter %s... careful!", "I smell a hunter %s. Stay close?"], "bold": ["Hunter %s! Let's get 'em!", "Fresh target %s!"],
		"curious": ["Someone's %s. Who is that?", "Hunter %s, I can hear them."], "_": ["Hunter %s!", "Rival %s, careful!", "Someone's coming %s!"]},
	"sniper": {"timid": ["Sniper %s! Get down!", "Long gun %s, stay in cover!"], "_": ["Sniper %s!", "Long gun %s, keep moving!"]},
	"pack": {"timid": ["So many teeth %s... go around?", "A whole pack %s!"], "bold": ["A pack %s! Bring it on!", "Monsters %s, let's clear them!"],
		"_": ["Monster pack %s.", "Lots of them %s, careful."]},
	"boss": {"timid": ["Something huge is fighting at %s...", "That roar... %s. Do we have to?"], "bold": ["Boss fight at %s! Let's go take it!", "Hear that? %s! Let's crash it!"],
		"_": ["A boss is awake at %s.", "Big fight at %s!"]},
	"egg": {"_": ["A Rare Egg! Over here!", "I can see an egg glowing! This way!"]},
	"loot": {"curious": ["Ooh, a %s! Over here!", "Shiny %s! Can we look?", "There's a %s, I found it!"], "_": ["%s over here!", "Found a %s!"]},
	"wild": {"curious": ["A wild %s! Can we say hi?", "Look, look, a %s!"], "_": ["A wild %s nearby.", "I smell a %s."]},
	"exit": {"_": ["The way out is %s!", "Exit's open %s. This way!"]},
	"collapse": {"timid": ["The islands are falling! Exit %s, hurry!"], "_": ["We have to go! Exit %s!", "Time to leave, this way, %s!"]},
	"low_hp": {"loyal": ["You're hurt... please drink something.", "Stay behind me, you're bleeding."], "timid": ["You're hurt! Let's hide and heal!", "Please be okay..."],
		"bold": ["You look rough. Patch up, I'll hold them.", "Heal up, partner. I've got this."], "_": ["You're hurt! Heal up!", "Careful, you're low!"]},
	"tonic": {"_": ["I found this for you! Drink it!", "Here, a tonic! I sniffed it out.", "Take it. You need it more than me."]},
	"cover": {"bold": ["Reload! I've got them!", "Go on, reload. I'm right here."], "_": ["I'll cover you!", "Reload, I'll watch them!"]},
	"goad": {"_": ["They're almost done! Finish it!", "One more hit!", "Don't let them get away!"]},
	"yelp": {"timid": ["Eek! Are you okay?!", "Ow ow ow! Watch out!"], "_": ["Hey! Are you okay?", "That one hurt!", "Ouch! Careful!"]},
	"relief": {"_": ["You're up! Don't scare me like that.", "Phew. Stay with me.", "There you are."]},
	"boss_kill": {"bold": ["We did it! We beat it!", "Ha! Nothing beats us!"], "_": ["We beat it! We actually beat it!", "It's down! You were amazing!"]},
	"comfort": {"_": ["It's okay. We'll get them next time.", "I'm still here. Let's go home.", "We'll come back stronger."]},
	"extract": {"timid": ["We made it! We actually made it!", "Home, home, home!"], "bold": ["Ha! Nobody stops us!", "What a run! Let's go home!"],
		"_": ["We made it! Home time!", "We did it! Let's go home!", "What a run, partner!"]},
}

## What a young kin's body says when it can't say the words (shown in brackets after its name).
const CALL_ACT := {
	"behind": "(spins round, growling behind you)", "hunter": "(growls toward a hunter)", "sniper": "(ducks low and stares off far away)",
	"pack": "(bristles at the monsters ahead)", "boss": "(ears flat, staring at the big fight)", "egg": "(bounces and points at a glowing egg)",
	"loot": "(points its nose at something shiny)", "wild": "(perks up at a wild Boki)", "exit": "(trots toward the way out, looking back)",
	"collapse": "(tugs you toward the way out)", "low_hp": "(nudges your hand, worried)", "tonic": "(drops a tonic at your feet)",
	"cover": "(plants itself in front of you)", "goad": "(bounces, egging you on)", "yelp": "(flinches with you)",
	"relief": "(nuzzles you hard)", "boss_kill": "(bounces in happy circles)", "comfort": "(presses against your leg)",
	"extract": "(bounces in happy circles by the way home)",
}

## Tutorial hints in its own voice, by step (grown speech, then what a hatchling does instead).
const TUT_HINT := {
	"move": ["Come on, let's look around!", "(runs a little circle and looks back at you)"],
	"dash": ["Dash across, like this!", "(zips off to the side and back, showing you)"],
	"glide": ["Jump, then glide! Watch me!", "(hops high and spreads out, showing you)"],
	"shoot": ["A monster! Get it!", "(growls at the monster)"],
	"sig": ["Press %E for %N! Line them all up, then fire!", "(bounces, ready for the group)"],
	"fight": ["Together! Get them all!", "(bristles, ready to fight)"],
	"throw": ["Throw me! I'm ready!", "(crouches on your shoulder, ready to jump)"],
	"chest": ["A chest! Open it with the key you got!", "(runs to a chest and paws at the lock)"],
	"extract": ["We did it! Into the light!", "(bounces toward the light)"],
}

static func dominant(k) -> String:
	var best := "bravery"; var bv := -1.0
	for key in ["bravery", "loyalty", "temper", "curiosity"]:
		var v: float = k.t(key)
		if v > bv:
			bv = v; best = key
	return best

static func line(k, cat: String, extra := "") -> String:
	# young kin can only say their own name (and a word or two once they trust you)
	var stage := Care.speech(k.rec) if k.rec.size() > 0 else 3
	if stage < 2 or (stage == 2 and randf() < 0.5):
		var rc: Dictionary = k.rec if k.rec.size() > 0 else {"species": k.species}
		return KinSpeak.bark(rc, cat if not (cat == "revive" and k.trust < 25.0) else "revive_low")
	var c := cat
	if cat == "revive" and k.trust < 25.0:
		c = "revive_low"
	var custom: Array = k.lines.get(c, [])
	var pool: Array = []
	if custom.size() > 0 and randf() < 0.75:
		pool = custom
	else:
		var cat_d: Dictionary = BASE.get(c, {})
		if cat_d.has("_"):
			pool = cat_d["_"]
		else:
			pool = cat_d.get(dominant(k), [])
	if pool.is_empty():
		return ""
	var s: String = pool.pick_random()
	if "%s" in s:
		s = s % extra
	return s

## A teammate callout (KinCompanion) in its own talking level: a hatchling says its name in the
## right tone and shows what it means; words come with level and trust (Care.speech).
static func callout(k, cat: String, extra := "") -> String:
	var stage := Care.speech(k.rec) if k.rec.size() > 0 else 3
	if stage < 2 or (stage == 2 and randf() < 0.4):
		var rc: Dictionary = k.rec if k.rec.size() > 0 else {"species": k.species}
		var s := KinSpeak.bark(rc, cat)
		return s + (" " + String(CALL_ACT[cat]) if CALL_ACT.has(cat) else "")
	var d: Dictionary = CALL.get(cat, {})
	var nat: String = k.comp.nature() if k.get("comp") else "_"
	var pool: Array = d.get(nat, d.get("_", []))
	var custom: Array = k.lines.get(cat, [])
	if custom.size() > 0 and randf() < 0.5:
		pool = custom
	if pool.is_empty():
		return ""
	var s: String = pool.pick_random()
	if "%s" in s:
		s = s % (extra if extra != "" else "nearby")
	return s.substr(0, 1).to_upper() + s.substr(1)

## Its hint for a tutorial step.
static func tut_hint(k, id: String) -> String:
	if not TUT_HINT.has(id):
		return ""
	var stage := Care.speech(k.rec) if k.rec.size() > 0 else 3
	if stage >= 2:
		return TutorialText.fill(String(TUT_HINT[id][0]), k.owner_h)
	var rc: Dictionary = k.rec if k.rec.size() > 0 else {"species": k.species}
	return KinSpeak.bark(rc, "tut") + " " + TutorialText.fill(String(TUT_HINT[id][1]), k.owner_h)
