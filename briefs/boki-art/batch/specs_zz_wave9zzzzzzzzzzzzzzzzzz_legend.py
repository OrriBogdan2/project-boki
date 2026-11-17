# 14:36 ET 11-09 owner asked about legendaries. Full-parser roster check: Cetorgan (legendary), Ghoulamari and Glacione (rares)
# never had art or a job (my 12:45 audit's heading regex skipped the rare/legendary sections). Two directions each:
# _gp = the roster design as written; _gq = the same design pushed bigger and more iconic (rares and legendaries should feel special).
_EXTRA={'Cetorgan':" Make it awe-inspiring and legendary: colossal scale, a grand silhouette that reads at a glance, calm and ancient, more mythic than any normal Boki.",
        'Ghoulamari':" Make it unforgettable and rare: a bold, eerie silhouette, the crystal-ball mantle as the clear focal point, mysterious rather than gross.",
        'Glacione':" Make it unforgettable and rare: an elegant, iconic silhouette, delicate but dangerous, the hidden fanged mouth just showing."}
for _n in ('Cetorgan','Ghoulamari','Glacione'):
    d=ROSTER200[_n]
    for _sfx,_add in (('gp',''),('gq',_EXTRA[_n])):
        SPECS.append({'id':f'c_{_n.lower()}_{_sfx}','name':_n+' (concept)','refs':[SRA],'runs':4,'aspect':'1:1',
          'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is the style reference only (soft hand-painted shading, clean thin dark outline, big glossy eyes); never copy its creatures. "
            "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "
            +CORE+LESSONS+"Concept: "+d['concept']+" Look: "+d['look']+" Face: "+d['face'].rstrip('.')+". Colours: "+d['cols'].rstrip('.')+". Archetype: "+d['arch'].rstrip('.')+". Avoid: "+d['avoid'].rstrip('.')+"."+_add)})
