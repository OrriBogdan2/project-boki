# Owner 03:43 ET 11-09: "canvastross needs a rework, really boring and low impact t3" (final of Kerchick > Jibbatross > Canvastross).
import os as _o76
_CV=next(f'briefs/boki-art/{d}/{n}.jpg' for n in ('Jibbatross','Canvastross') for d in ('turnarounds','evolutions') if _o76.path.exists(HERE.parent/d/f'{n}.jpg'))
_P76=[]
_AVS="a ship it rides, a rider, ropes tied on, standing upright like a person, a busy design"
for _k,_b in (('s1',"A colossal storm albatross with an enormous wingspan, each wing a full billowing canvas mainsail on mast-like wing bones, a tall crow's-nest crest, a hooked beak like a ship's prow, and a tail of trailing pennant flags, braced on a rocky perch with wings raised."),
              ('s2',"A huge galleon albatross: its chest a curved wooden ship's hull with brass portholes, three tiers of canvas sails as wings spread wide, a carved figurehead face crest, and a long rudder tail, planted and towering."),
              ('s3',"An epic sky-pirate albatross with tattered black-and-cream sails as wings that crackle with wind, a skull-and-crossbones pattern faint in the sail, a hooked beak and a crest like a captain's tricorn, looming forward with wings half spread."),
              ('s4',"A massive wind-god albatross gliding low with sails for wings filled by swirling gusts, a broad white chest with rope-knot patterns, a tall mast crest with a fluttering flag, and a fanned tail of stacked sails."),
              ('s5',"A giant clipper-ship albatross diving with wings swept back into sharp triangle sails, sleek and fast, a long bowsprit beak, brass trim along its wing edges, and a tail of long streaming pennants.")):
    VC('canvastross_'+_k,'Canvastross',_CV,'final',_b+" A big, high-impact final form. One clear idea, few parts.","fierce, proud sea-blue eyes","cream canvas and ocean blue, with brass and red accents",_AVS,'tempest','majestic'); _P76.append('c_canvastross_'+_k)
PRIORITY=_P76+PRIORITY
