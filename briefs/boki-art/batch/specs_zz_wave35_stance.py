# Owner 00:28 ET 11-09: "variety in the poses for evolutionary trees ... crucial across the board". Line audit
# (stance_audit.json, 31 lines) assigned each stage a stance on the ladder. Re-pose every approved sheet that needs it:
# a fresh turnaround from the sheet with the design kept exactly (edits can't change a pose). Vespyx line first.
import json as _j35
_SKIP={'Prismander','Glassolotl','Chandelotl','Geodelotl'}   # being redesigned (owner 00:27)
_P35=[]; _first=[]
for _a in _j35.load(open(HERE/'stance_audit.json')):
    _n=_a['stage']
    if not _a.get('redo') or _n in _SKIP: continue
    _src=next((f'briefs/boki-art/{d}/{_n}.jpg' for d in ('evolutions','turnarounds') if (HERE.parent/d/f'{_n}.jpg').exists()),None)
    if not _src or 'OLD DESIGN' in _a.get('current','').upper(): continue
    SPECS.append({'id':'stance_'+_n.lower(),'name':_n+' (new stance)','refs':[_src],'runs':3,'aspect':'16:9',
      'prompt':("Character turnaround sheet of exactly the creature in image 1: the same design, proportions, colours, markings, face, eyes and every detail, "
                "nothing added or removed, in the same soft hand-painted style with a clean, fairly thin dark outline. Only its stance changes: "+_a['new_stance']+
                " Exactly four views of it in this same new stance in one clean row: front, three-quarter, side and back, the same size, "
                "plain flat pale grey background, no text, no shadows, no floor, no ghost or faded copies, nothing else in the image.")})
    (_first if _a['line'] in ('Vespyx','Mycroll','Ermink') else _P35).append('stance_'+_n.lower())
PRIORITY=_first+PRIORITY+_P35
