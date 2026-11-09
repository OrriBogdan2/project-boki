# Roster 200 (owner OK 22:14 ET): concept-first pipeline for the 77 new species in ROSTER_200_NEW.md.
# Step 1: one square concept image per species (c_<name>), judged by the panel on design alone.
# Step 2: approved concepts get a turnaround sheet made from the concept (TA()).
# Families top-down: only first stages, rares and legendaries are queued now; later stages follow once the
# previous stage's concept passes (CQ() calls added in later rounds, using the approved parent concept as image 2).
import re as _re
_R200=open(HERE.parent/'ROSTER_200_NEW.md').read()
def _field(block,name):
    m=_re.search(r'\*\*'+name+r':\*\*\s*(.+)',block); return m.group(1).strip() if m else ''
ROSTER200={}
_parts=_re.split(r'\n(?=### |## \d+\. )',_R200)
for _p in _parts:
    m=_re.match(r'(?:### |## \d+\. )([A-Z][A-Za-z]+)\s*(\(([^)]*)\))?',_p)
    if not m or '**Look:**' not in _p: continue
    ROSTER200[m.group(1)]={'stage':m.group(3) or 'single','concept':_field(_p,'Concept'),'look':_field(_p,'Look'),
        'face':_field(_p,'Face'),'cols':_field(_p,'Colours'),'avoid':_field(_p,'Avoid'),'arch':_field(_p,'Archetype')}
CONCEPT_CORE=("Creature-collector monster concept art for a fantasy action game, painted in exactly the soft hand-painted style of image 1 "
 "(clean, fairly thin dark outline, painterly shading, stylised and appealing), but a brand-new creature: never copy any creature from image 1. "
 "ONE creature only, full body, in a natural three-quarter view and a pose with personality, centred and filling about 85 percent of the square, "
 "plain flat light grey background, no text, no effects, no scenery. It is clearly an animal: no human posture, nothing held, worn or strapped; "
 "its idea grows through its whole body. ")
def CQ(name,parent_concept=None,runs=4):
    d=ROSTER200[name]
    refs=[SR]+([parent_concept] if parent_concept else [])
    fam=(" Image 2 is the earlier form of this creature: keep its face shape, eye colour and palette so the family reads, "
         "but give this form a fundamentally new body plan, silhouette and pose.") if parent_concept else ""
    SPECS.append({'id':'c_'+name.lower(),'name':name+' (concept)','refs':refs,'runs':runs,'aspect':'1:1',
      'prompt':CONCEPT_CORE+LESSONS+"Concept: "+d['concept']+" Look: "+d['look']+" Face: "+d['face']+". Colours: "+d['cols']+
               ". Archetype: "+d['arch']+". Avoid: "+d['avoid']+fam})
def TA(name,concept_path):
    d=ROSTER200.get(name,{})
    SPECS.append({'id':'ta_'+name.lower(),'name':name,'refs':[concept_path],'runs':2,'aspect':'16:9',
      'prompt':("Character turnaround sheet of exactly the creature in image 1: the same design, proportions, colours, markings, face and "
                "every detail, nothing added or removed, in the same soft hand-painted style. Exactly four views of it in one clean row: "
                "front, three-quarter, side and back, the same size, standing or crawling naturally like an animal, neutral pose, "
                "plain flat pale grey background, no text, no shadows, no ghost copies, nothing else in the image.")})
SPORE_NOTE=(' If this is a Spore-type creature: keep it appealing, and use the Blight palette only as a small accent '
 '(purple-black gills or vein lines, a faint purple inner glow in its spores, a few small bone-spur quills); never green slime, never gross or rotting.')
_TYPES={m.group(1):m.group(2) for m in _re.finditer(r'^(?:### |## \d+\. )([A-Z][A-Za-z]+)[^\n]*·\s*([A-Za-z ,]+?)\s*(?:\(|$)',_R200,_re.M)}
_FIRST=[n for n,d in ROSTER200.items() if d['stage'].startswith('1 of') or d['stage'] in ('single','rare') or 'of' not in d['stage']]
for _n in _FIRST: CQ(_n)

for _x in SPECS:
    if _x['id'].startswith('c_'):
        _nm=_x['name'].split(' (')[0]
        if 'Spore' in _TYPES.get(_nm,'') and SPORE_NOTE not in _x['prompt']: _x['prompt']+=SPORE_NOTE
