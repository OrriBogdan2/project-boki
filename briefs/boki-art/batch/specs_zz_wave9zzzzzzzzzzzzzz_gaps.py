# 12:45 ET 11-09 owner (chat 12:43): "check for other alt forms that need genning and also boki in general and make sure it's in queue".
# Audit: 25 ROSTER_200 species have no live art and no pending job (earlier concepts never passed or were never queued).
# Queued now: first stages, and later stages whose previous stage has live art (its card = family ref, image 1).
# Chained after the owner picks the parent concept: Critwom (Pipwom), Klaxada > Sirencada (Mumblet), Checkmare (Gambitfin),
# Pickadactyl (Chiptero), Parrywhal (Narfoil), Tiltster (Pinster), Pagoguana (Pagodito).
# Alt forms: female looks (GAME_RULES 6 + ROSTER_200 special rules) from the current live cards. Babies differ little, so skipped.
# Arcestrel and Gongrowl females wait for their redesign picks; Hourachnid and Pavonazar females wait for their designs.
_C='briefs/boki-art/cards/'
def _GAP(name,rel=None,parent=None,runs=4):
    d=ROSTER200[name]
    refs=([_C+parent+'.jpg'] if parent else [])+[SRA]
    lead=(REL[rel]+" Image 1 is "+parent+"; do not copy its pose. Image 2 is the style reference only; never copy its creatures. ") if parent else \
         "Image 1 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
    SPECS.append({'id':'c_'+name.lower()+'_gp','name':name+' (concept)','refs':refs,'runs':runs,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+lead+
        "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "
        +CORE+LESSONS+"Concept: "+d['concept']+" Look: "+d['look']+" Face: "+d['face'].rstrip('.')+". Colours: "+d['cols'].rstrip('.')+". Archetype: "+d['arch'].rstrip('.')+". Avoid: "+d['avoid'].rstrip('.')+".")})
    if 'Spore' in _TYPES.get(name,''): SPECS[-1]['prompt']+=SPORE_NOTE
# first stages and singles (no live relative)
for _n in ('Mumblet','Chiptero','Narfoil','Pinster','Pagodito','Pavonazar'): _GAP(_n)
# babies of live Boki (image 1 = the grown form)
for _n,_p in (('Bullpole','Bullsfrog'),('Pocketpus','Bladypus'),('Scoopsy','Sundormouse')): _GAP(_n,'baby',_p)
# later stages of live Boki (image 1 = the earlier form)
for _n,_rel,_p in (('Pipwom','mid','Cubbat'),('Gambitfin','mid','Pawnfry'),('Hourachnid','final','Sandwidow'),('Rosedart','final','Nymphane'),
                   ('Fanpire','final','Foldbat'),('Chainipede','final','Clinkpede'),('Scarabit','final','Orbitle'),('Meteorab','final','Orbitle')):
    _GAP(_n,_rel,_p)
# female looks (alt forms) of current live designs
for _n,_st in (('Furnacowary','final'),('Voltalon','final'),('Eclipsowl','final'),('Murmurling','mid'),('Murmuron','final'),('Sandwidow','mid'),('Grainspin','baby')):
    if _n=='Grainspin': continue  # baby: little or no difference
    SPECS.append({'id':f'c_{_n.lower()}_f_n','name':_n+' (female form concept)','refs':[_C+_n+'.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL['female']+
        "Image 2 is the style reference only; never copy its creatures. ONE creature only, full body, the same gentle three-quarter view and the same pose as image 1, "
        "centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "+CORE+LESSONS+
        "Keep everything that defines "+_n+" (its signature object, body plan, face and type) so it reads instantly as the same species; change only a few things the way real animals differ by sex: crest, tail or plumage shape, the size of its signature part, and a slightly different colour tint.")})
