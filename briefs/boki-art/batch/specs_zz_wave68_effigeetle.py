# Owner 03:37 ET 11-09: "effigeetle needs an evolution or no one will use it - maybe into a cocoon that is super defensive then into
# like a butterfly - but maybe he becomes more mechanical each time and comes out like an artillery butterfly". New 3-stage line:
# Effigeetle (marble statue-face beetle, gold horn) > [cocoon, working name Effigoon] > [artillery butterfly, working name Mortarfly].
# Each stage more mechanical (brass, gears, rivets) while keeping the marble statue face, gold horn and amber eyes.
_EF='briefs/boki-art/cards/Effigeetle.jpg'; _P68=[]
_AVE="a person, a statue of a person, standing upright like a human, held weapons, guns held in hands, explosions, effects, a busy design"
for _k,_b in (
 ('c1',"A heavy, armoured cocoon creature: a big egg-shaped marble shell hanging from a brass hook-tail, with the serene statue face carved on the front, riveted brass bands and small gears around it, the gold horn sticking out the top, and two amber eyes peering through a slit like a visor."),
 ('c2',"A super-defensive chrysalis knight: a smooth upright marble pod plated with overlapping brass armour scales like a pangolin, the carved statue face on its front, a gold horn crest, short stubby brass legs braced wide, and amber eyes glowing behind a riveted visor."),
 ('c3',"A clockwork cocoon fortress: a round marble pupa wrapped in brass cage bands with visible turning gears, the statue face carved into it with a calm smile, the gold horn as a little spire on top, sitting heavy and immovable on four short brass feet."),
 ('c4',"A mechanical chrysalis turtle-pod: a thick marble shell split into hinged armour plates edged in brass, half closed like a vault, the statue face on the lid, amber eyes peeking out from the gap, the gold horn folded down like a latch.")):
    VC('effigoon_'+_k,'Effigoon',_EF,'mid',_b+" Clearly Effigeetle's next form, more mechanical. One clear idea, few parts.","calm, serene carved statue face with glowing amber eyes","marble white and polished brass, with gold and amber accents",_AVE,'stone','tough'); _P68.append('c_effigoon_'+_k)
for _k,_b in (
 ('a1',"An artillery butterfly: a big marble-bodied butterfly with the carved statue face on its thorax, four huge mechanical wings of brass frames and stained marble panels, and two short brass mortar barrels grown into its shoulders pointing up, the gold horn as a rangefinder crest, hovering low and braced."),
 ('a2',"A heavy siege moth-butterfly: a broad armoured marble body on six brass legs planted wide, great brass-and-marble wings folded up behind it like artillery shields, a rack of small cannon tubes along each wing edge, and the serene statue face with a gold horn."),
 ('a3',"A clockwork war butterfly: elegant marble wings with gold veins and brass rivets spread wide, its abdomen a long riveted brass cannon barrel, gears turning at the wing roots, the statue face calm on its head and amber eyes glowing, standing planted on four brass legs."),
 ('a4',"A towering mechanical monarch: a tall marble-and-brass butterfly with wings like ornate brass fortress gates with round porthole cannon openings, a gold horn crown, the calm statue face, and a heavy armoured body on thick brass legs."),
 ('a5',"A sleek artillery swallowtail: long marble wings with brass frames tapering into tail streamers that end in small mortar tubes, a rotating brass turret ring around its thorax, the statue face on the front with a gold horn, perched planted on brass legs with wings raised.")):
    VC('mortarfly_'+_k,'Mortarfly',_EF,'final',"The final form of image 1's line, after a cocoon stage: "+_b+" Much more mechanical than image 1 but keeping its carved statue face, marble, gold horn and amber eyes. One clear idea, few parts.","calm, serene carved statue face with glowing amber eyes","marble white and polished brass, with gold and amber accents",_AVE,'stone','majestic'); _P68.append('c_mortarfly_'+_k)
PRIORITY=_P68+PRIORITY
