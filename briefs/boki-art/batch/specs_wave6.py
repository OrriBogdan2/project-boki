# Round 6 (20:32)
V('coolatee','Coolatee',T+'Frigatee.jpg','baby',"A tiny, round manatee calf lying on its belly, half the size of image 1, whose back is a little cream picnic cool-box lid with one small brass latch and a dusting of frost."+DIFF,"big, sleepy, sweet eyes and a tiny whiskery smile","cream and frost blue, with a brass accent","standing upright, food, looking like image 1",'frost','cute')
V('glaciatee','Glaciatee',T+'Frigatee.jpg','final',"A huge, ancient manatee lying on its belly whose whole back is a walk-in ice vault: a thick cream-and-steel vault door set into its back with a big brass wheel, glacier ice armour along its sides, and icicle tusks."+DIFF,"calm, deep, heavy-lidded eyes and a slow, gentle smile","cream and glacier blue, with a brass accent","standing upright, a building, looking like image 1",'frost','tough')
for _n,_d,_p in [('Dribbara',E,'splashing happily in its little back pool'),('Glassolotl',E,'gliding forward with rainbow light inside it'),('Frigatee',T,'lounging on its belly with frost drifting off its lid'),('Lanterloris',T,'creeping forward, its lantern belly glowing')]:
    P(_n.lower(),_n,_d+_n+'.jpg',_p)
for _x in SPECS:
    if _x['id'].startswith('portrait_'): _x['aspect']='1:1'
