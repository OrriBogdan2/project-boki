# 15:23 ET 11-09 owner round-5 picks (chat 15:22): all my picks, except Klaxada (face less scary), Pagoguana = standing version (gp_3),
# Glacione = redo ("looks weird"). Picks -> sheet ta_<n>_r5 + card <n>_card108 + portrait portrait_<n>_r5.
# Names for the new legendaries (proposed, owner can rename): Wayshell (minor), Siegephant (boss), Aurostag (ultra), Cindermaw and Sphinxblight (blight).
_O='briefs/boki-art/batch/out/'; _NOG=" Plain background only: no ground, no sand, no rocks, no base under it."
def _SET5(name,stem,stage,pose):
    s=_O+stem+'.jpg'; k=name.lower()
    TA(name,s); SPECS[-1]['id']=f'ta_{k}_r5'; SPECS[-1]['prompt']+=" Exactly ONE single row of four views, never two rows."+_NOG
    SPECS.append({'id':f'{k}_card108','name':name+' (hero card)','refs':[s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD(name,stage,pose)+_NOG})
    P(f'{k}_r5',name,s,pose); SPECS[-1]['prompt']+=_NOG
for _a in [
 ('Druzemole','c_druzemole_n1_4','final','reared up on its hind legs, its glittering geode-cave back open behind it, crystal claws spread wide'),
 ('Pipwom','c_pipwom_n1_2','mid','trundling forward with its ivory die-shield rump raised, stubborn squint'),
 ('Checkmare','c_checkmare_gp_2','final','rearing its long neck high, spines fanned, coiled tail planted'),
 ('Pickadactyl','c_pickadactyl_gp_3','final','wings half spread, pickaxe crest raised, braced on its feet'),
 ('Parrywhal','c_parrywhal_gp_2','final','swimming through the air with its sword tusk thrust forward like a fencer'),
 ('Tiltster','c_tiltster_gp_3','final','braced wide with its flipper arms raised, bumpers glowing'),
 ('Pagoguana','c_pagoguana_gp_3','final','standing tall on its hind legs with its pagoda spine towering, tail planted'),
 ('Cetorgan','c_cetorgan_gp_1','final','gliding through the sky, organ-pipe back raised, calm and colossal'),
 ('Ghoulamari','c_ghoulamari_gq_2','final','drifting with its webbed arms spread wide, crystal-ball mantle glowing'),
 ('Wayshell','c_leg_minor_n1_1','final','walking proudly with its compass needle glowing'),
 ('Siegephant','c_leg_boss_n3_3','final','braced wide and planted for battle, battering-ram trunk raised'),
 ('Aurostag','c_leg_ultra_n2_4','final','standing tall and majestic, aurora antlers glowing across the sky'),
 ('Cindermaw','c_leg_blight1_n1_3','final','prowling low, furnace ribs glowing white-hot, skull grin'),
 ('Sphinxblight','c_leg_blight2_n2_2','final','sitting tall like a sphinx with its ragged wings half spread'),
]: _SET5(*_a)
# Voltalon female look: sheet + card.
_s=_O+'c_voltalon_f_n2_2.jpg'
TA('Voltalon',_s); SPECS[-1]['id']='ta_voltalon_f_r5'; SPECS[-1]['prompt']+=" Exactly ONE single row of four views."+_NOG
SPECS.append({'id':'voltalon_f_card108','name':'Voltalon female (hero card)','refs':[_s,SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Voltalon','final','the same stalking pose as image 1')+_NOG})
# Klaxada: friendlier face first (edit), then the full set once the owner sees it.
SPECS.append({'id':'c_klaxada_soft','name':'Klaxada (softer face)','refs':[_O+'c_klaxada_gp_1.jpg'],'runs':4,'aspect':'1:1',
  'prompt':"Edit image 1: keep everything exactly the same: the same creature, brass horn, wings, body, colours, pose, style and plain background. Only change its face: make it friendlier and less scary, with bigger rounder glossy eyes and a small closed or gently smiling mouth, no fangs, no angry brow. Do not add anything else."})
# Glacione redo ("looks weird"): drop the cork-head shuttlecock read; a cute frost sea angel first, shuttlecock only as a hint.
for _k,_b in enumerate([
 "A small, cute frost sea angel (clione) floating upright: a translucent ice-blue teardrop body, two little wing-lobes flapping like an angel, frosted crystal tips on the lobes, a tiny silver crescent glowing in its belly, a simple round head.",
 "A chubby frost sea angel whose two wing-lobes and a short skirt of frosted feather-lobes make it look a little like a shuttlecock in flight, translucent ice body, a cute round face.",
 "A tiny frost sea angel with a frilly snowflake-crystal skirt and two fluttering wing-lobes, curled mid-swim, translucent glowing body, a sweet face that hides a small fanged smile."],1):
    SPECS.append({'id':f'c_glacione_n{_k}','name':'Glacione (concept)','refs':[SRA],'runs':4,'aspect':'1:1',
      'prompt':("Creature-collector monster concept art for a fantasy action game. Image 1 is the style reference only; never copy its creatures. "
        "ONE creature only, full body, gentle three-quarter view, centred with about 8 percent margin, plain flat pale grey background, no shadow, no ground, no text. "
        +CORE+LESSONS+"A Minor legendary: normal Boki size, rare, one standout feature. "+_b+" Colours: ice blue and clear white, with a silver accent. Avoid: a cork or brown head, a racket, a human angel, a halo. One clear idea, few parts.")})
# STYLE TEST (owner 15:16 'not AI slop'): 6 Boki x 3 cleaner styles, same designs. Owner picks a style before any re-render.
_STY={'a':("Flat cel-shaded official creature-collector art: bold clean even-weight dark outlines, flat colour fills with only one or two hard-edged shadow tones, "
           "no gradients, no airbrush, no glossy plastic shine, no texture, no sparkles, simple clean shapes."),
      'b':("Hand-inked illustration: confident ink linework with natural line-weight variation, flat watercolour-wash colour with a little paper texture, "
           "minimal shading, no gloss, no airbrush gradients, no sparkles; it should look drawn by a person."),
      'c':("Chunky simplified toy-like design: big bold simple shapes, thick outline, flat colours with one soft shadow, very few details, "
           "no small rivets or filigree, no texture, no gloss, no sparkles; reads instantly at icon size.")}
for _n,_st in (('Vespyx','baby'),('Mycroll','baby'),('Chandelotl','final'),('Gongrowl','final'),('Glaciammoth','final'),('Rimink','final')):
    for _k,_txt in _STY.items():
        SPECS.append({'id':f'style_{_n.lower()}_{_k}','name':f'{_n} (style test {_k})','refs':[f'briefs/boki-art/cards/{_n}.jpg'],'runs':2,'aspect':'1:1','size':'2K',
          'prompt':("Redraw the creature in image 1 as a single character illustration. Keep the design exactly: the same creature, body, face, colours, markings, "
            "signature parts and pose. Change ONLY the rendering style to this: "+_txt+" Plain flat pale grey background, no ground, no shadow, no text. One creature only, whole body in frame, centred.")})
