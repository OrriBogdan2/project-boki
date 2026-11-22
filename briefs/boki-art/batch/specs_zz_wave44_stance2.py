# Stance redos that failed twice as sheet re-poses (the model keeps the old pose when redrawing a whole sheet). New path, the one that
# worked for portraits: one square image of the creature in the new stance from its sheet; the turnaround follows from that image.
import json as _j44
_aud={a['stage']:a for a in _j44.load(open(HERE/'stance_audit.json'))}
_FAIL2=['Bellowary','Boltstrich','Chandelapi','Flarmink','Galleotter','Latchling','Rimink','Ringrove','Snuffapi','Soakybara','Sporcupine','Voltmink','Lockatara','Prowyak','Puffamus','Frigatee']
_P44=[]
for _n in _FAIL2:
    _src=next((f'briefs/boki-art/{d}/{_n}.jpg' for d in ('evolutions','turnarounds') if (HERE.parent/d/f'{_n}.jpg').exists()),None)
    if not _src or _n not in _aud: continue
    P('stance2_'+_n.lower(),_n,_src,_aud[_n]['new_stance']+" This stance is the whole point of the image: it must be clearly different from the pose in image 1.")
    SPECS[-1]['runs']=3; SPECS[-1]['prompt']=SPECS[-1]['prompt'].replace("an interesting, characteristic pose full of personality and attitude","exactly this stance")
    _P44.append('portrait_stance2_'+_n.lower())
PRIORITY=_P44+PRIORITY
