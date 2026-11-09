# 14:32 ET 11-09 owner round-4 picks (chat 14:30): my picks everywhere except Arcestrel = n3_3, Bullsfrog final = n3_3,
# Pipwom = redo (face/leg anatomy bugged). Every pick -> sheet (ta_<n>_r4) + hero card (<n>_card104) + portrait (portrait_<n>_r4).
# New names proposed (owner can rename): Shinobant (owner 13:35), Harvantis (Scythant-route final), Bulwartoad (Buckleron T2),
# Barostorm (Barokat final), Quivertoad (Bullsfrog final), Bonsolith (Pangolith final). Anchorhorn keeps its file name; display name Harpwhal.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
_NOG=" Plain background only: no ground, no sand, no rocks, no base under it."
def _SET(name,stem,stage,pose):
    s=_O+stem+'.jpg'; k=name.lower()
    TA(name,s); SPECS[-1]['id']=f'ta_{k}_r4'; SPECS[-1]['prompt']+=" Exactly ONE single row of four views, never two rows."+_NOG
    SPECS.append({'id':f'{k}_card104','name':name+' (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(name,stage,pose)+_NOG})
    P(f'{k}_r4',name,s,pose); SPECS[-1]['prompt']+=_NOG
_PICKS=[
 ('Arcestrel','c_arcestrel_n3_3','mid','sprinting forward on its long legs, copper-wire tail streaming behind, crest raised, beak open in a grin'),
 ('Soakybara','c_soakybara_n3_1','mid','belly-sliding forward like a sled, its hot-spring back steaming, grinning with squinted eyes'),
 ('Geysirbara','c_geysirbara_n2_4','final','sitting up on its haunches like a sumo, chest out, steam rising from its travertine back'),
 ('Lockatara','c_lockatara_n2_1','mid','low mid-pounce with its tumbler-pin spikes raised and its key tail lashing'),
 ('Glazolm','c_glazolm_n2_2','mid','swimming through the air in a graceful S-curve, porcelain gills fanned'),
 ('Slog','c_slog_n1_1','mid','oozing forward with its three eye-stalks up and curious'),
 ('Crofthorn','c_crofthorn_n1_2','baby','standing sturdy with its plough-blade garden wall on its back, a curious little huff'),
 ('Anchorhorn','c_anchorhorn_n1_4','final','braced low on its flippers with its harpoon tusk thrust forward'),
 ('Spanglin','c_spanglin_n2_2','baby','sitting splay-legged with its sequin ruff fanned up, beaming'),
 ('Tinbrock','c_tinbrock_n2_1','baby','sitting up chubby and curious, copper fur sparkling with blue sparks'),
 ('Shinobant','c_reapant_t2g_4','mid','compact ninja ant mid-stride, one leaf-scythe raised, red eyes glinting'),
 ('Reapant','c_reapant_t3n3_4','final','looming tall over the viewer like a reaper, blade wings spread wide, scythes raised'),
 ('Harvantis','c_scythant_t3n1_4','final','planted wide with its leaf-scythe forelegs crossed, fern crown raised high'),
 ('Lurklet','c_lurklet_n2_2','baby','bobbing happily with its little lure glowing'),
 ('Bulwartoad','c_buckleron_ev1_2','mid','prowling low under its tower-shield shell, spike boss forward'),
 ('Barostorm','c_barokat_ev1_4','final','standing tall like a sentinel meerkat, storm mane swirling, barometer belly glowing'),
 ('Quivertoad','c_bullsfrog_t3n3_3','final','braced low and wide with its fletched quills bristling, glaring'),
 ('Bonsolith','c_terrasloth_t2n3_2','final','coiled and planted with its blossom tree raised proudly on its back'),
]
for _g,_r in [('mumblet','_3'),('chiptero','_3'),('narfoil','_3'),('pinster','_1'),('pagodito','_2'),('pavonazar','_4'),('bullpole','_1'),('pocketpus','_2'),('scoopsy','_1'),
              ('gambitfin','_2'),('hourachnid','_1'),('rosedart','_3'),('fanpire','_2'),('chainipede','_2'),('scarabit','_3'),('meteorab','_3')]:
    _n=_g.capitalize(); _st=ROSTER200[_n]['stage']
    _stage='final' if (_st in ('single','rare') or 'of' not in _st or _st.split(' of ')[0]==_st.split(' of ')[1]) else ('baby' if _st.startswith('1 of') else 'mid')
    _PICKS.append((_n,f'c_{_g}_gp{_r}',_stage,'a characterful pose that shows off its signature feature, exactly true to its design in image 1'))
for _a in _PICKS: _SET(*_a)
# Female looks (alt forms): sheet + card. Voltalon waits for the rock-free redo.
for _n,_stem,_st in [('Furnacowary','c_furnacowary_f_n_4','final'),('Eclipsowl','c_eclipsowl_f_n_4','final'),('Murmurling','c_murmurling_f_n_2','mid'),('Murmuron','c_murmuron_f_n_1','final'),('Sandwidow','c_sandwidow_f_n_4','mid')]:
    _s=_O+_stem+'.jpg'
    TA(_n,_s); SPECS[-1]['id']=f'ta_{_n.lower()}_f_r4'; SPECS[-1]['prompt']+=" Exactly ONE single row of four views."+_NOG
    SPECS.append({'id':f'{_n.lower()}_f_card104','name':_n+' female (hero card)','refs':[_s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(_n,_st,'the same characterful pose as image 1')+_NOG})
# Tinbrock line palette (owner picked copper fur + blue sparks): recolour Anvilbrock and Forgebrock cards and sheets to match.
_PAL=("recolour it to match its new baby form: warm copper-bronze fur, a soot-grey face mask, and blue-white spark cracks instead of the orange lava cracks; "
      "metal parts stay dark iron. Keep the design, pose and everything else exactly the same.")
for _n in ('Anvilbrock','Forgebrock'):
    SPECS.append({'id':f'{_n.lower()}_card104','name':_n+' (hero card recolour)','refs':[_C+_n+'.jpg'],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':"Edit image 1: keep everything exactly the same: the same creature, design, pose, style and plain pale grey background. Only change this: "+_PAL})
    X(f'ta_{_n.lower()}_r4',_n,'briefs/boki-art/evolutions/'+_n+'.jpg',_PAL)
# Pipwom redo (owner: face/arm placement looked bugged): Boki proportions, clear anatomy.
for _k,_b in enumerate([
 "A stocky wombat cub-grown-up walking on all four legs, a big round head with big glossy eyes clearly at the FRONT of its body, four separate legs each clearly attached under the body, its rump grown into a big ivory six-pip die shield, small pip dots down its spine.",
 "A low, wedge-shaped burrowing wombat mid-dig with big spade claws on its two front legs, head up and facing forward with big eyes and a stubborn squint, its back end rising into a big ivory die-shield rump with six black pips.",
 "A chunky wombat bracing on all fours with its head turned toward the viewer, ivory caps on its brow and claw tips, its rump a squared ivory die plate with six pips, clean simple anatomy: one head, four legs, one rump."],1):
    VC(f'pipwom_n{_k}','Pipwom',_C+'Cubbat.jpg','mid',_b+" Full body, no crop, no ground. One clear idea, few parts.",'a stubborn squint and a jutting lower jaw','earth brown and bone ivory, with black pip accents','a realistic wombat, a separate die sitting on its back, extra limbs, a face on its side, numbers, text','wild','tough')
# Next stages now that their parents are picked (concepts first; the owner picks on the A/B page).
for _n,_rel,_p in [('Klaxada','mid','c_mumblet_gp_3'),('Checkmare','final','c_gambitfin_gp_2'),('Pickadactyl','final','c_chiptero_gp_3'),('Parrywhal','final','c_narfoil_gp_3'),('Tiltster','final','c_pinster_gp_1'),('Pagoguana','final','c_pagodito_gp_2')]:
    d=ROSTER200[_n]
    SPECS.append({'id':'c_'+_n.lower()+'_gp','name':_n+' (concept)','refs':[_O+_p+'.jpg',SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. "+REL[_rel]+" Image 2 is the style reference only; never copy its creatures. "
        "ONE creature only, full body, gentle three-quarter view with the head turned toward the viewer, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text, no effects. "
        +CORE+LESSONS+"Concept: "+d['concept']+" Look: "+d['look']+" Face: "+d['face'].rstrip('.')+". Colours: "+d['cols'].rstrip('.')+". Archetype: "+d['arch'].rstrip('.')+". Avoid: "+d['avoid'].rstrip('.')+".")})
