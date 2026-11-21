# Owner 01:16 ET 11-09: Zippelith "is glitched and shows too much" — the upright column worm with a zipper down its front reads
# wrong. Re-pose and re-shape it: low inchworm arch, wide round head, zipper along the TOP of the back only.
_ZS='briefs/boki-art/turnarounds/Zippelith.jpg'
SPECS.append({'id':'zippelith_fix','name':'Zippelith (fix)','refs':[_ZS],'runs':4,'aspect':'16:9',
 'prompt':("Character turnaround sheet of the creature in image 1, keeping its glossy black body, purple zipper glow, face, big eyes and blush, "
   "but change its shape and stance: it is NEVER upright. A long, low, chunky worm inching forward along the ground in an inchworm arch "
   "(its middle humped up in a soft arch, both ends on the ground), a wide, round, slightly flattened head held low and forward with a bigger, friendlier face, "
   "and the zipper running only along the top ridge of its back from the head to the tail, with a small zipper pull at the tail tip. "
   "Nothing down its front or belly. Exactly four views of it in this same pose in one clean row: front, three-quarter, side and back, the same size, "
   "plain flat pale grey background, no floor line, no shadows, no text, no ghost copies.")})
P('zippelith_fix','Zippelith',_ZS,"inching forward low along the ground in an inchworm arch with its wide round head low and forward toward the viewer, the zipper running along the top of its arched back; never upright")
SPECS[-1]['runs']=4
PRIORITY=['zippelith_fix','portrait_zippelith_fix']+PRIORITY
