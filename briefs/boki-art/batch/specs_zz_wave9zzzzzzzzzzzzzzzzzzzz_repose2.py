# 15:16 ET 11-09 look-alike re-pose, second try. CARD()-based re-poses kept the old pose (the card ref anchors it, and CARD bans
# upright/attack poses). This version uses the SHEET as identity ref and a pose-first prompt without those limits (as gongrowl_cardx did).
def _SHEET(n):
    for d in ('evolutions','turnarounds'):
        if (HERE.parent/d/f'{n}.jpg').exists(): return f'briefs/boki-art/{d}/{n}.jpg'
def _RP2(n,pose):
    SPECS.append({'id':f'{n.lower()}_card107','name':n+' (hero card, new pose)','refs':[_SHEET(n),SRA],'runs':3,'aspect':'1:1','size':'2K',
      'prompt':("Single character illustration of one Boki (a stylised creature-collector monster): "+n+", the creature shown in the turnaround sheet in image 1, redrawn in the Boki house style of image 2. "
        "Image 1 is the identity reference only: keep exactly the same creature, design, face, colours, markings and signature parts; ignore its views, poses and layout. "
        "Image 2 is the style reference only (ignore its dark backdrop): soft hand-painted shading, clean fairly thin dark outline, big glossy eyes; never copy its creatures. "
        "POSE (most important, the whole point of this image): "+pose+" This pose must be clearly different from every view in image 1. "
        "One creature only, the whole body in frame, centred, big in the frame, about 8 percent margin. Plain flat pale grey (#E8E8EE) background, no ground, no rocks, no shadow, no glow halo, no text.")})
for _n,_p in [
 ('Geodemole','lunging forward mid-dig, body stretched long and low to the ground, both crystal claws thrown far forward, tail streaming behind, seen from a dynamic three-quarter angle.'),
 ('Rattlebub','a tiny baby snake bouncing upright on its tail like a spring, body in a big loose loop, rattle shaking in the air, wide happy eyes.'),
 ('Maracoil','reared up tall like a striking cobra, head high above a big planted coil, mouth open showing fangs, both maraca rattles raised high and shaking, menacing.'),
 ('Gravitank','braced wide and charging straight at the viewer, head lowered, horn forward, its huge cratered shell raised behind like a mountain, debris floating.'),
 ('Forgebrock','reared up on its hind legs like a roaring bear, front paws raised, forge chest glowing blue-white, copper fur.'),
 ('Frigatee','gliding forward on its belly through the air like a seal sliding on ice, flippers swept back, cooler-lid back trailing cold mist.'),
 ('Scopeleon','creeping forward mid-stride, body low and long, telescope eye stretched forward toward the viewer, tail curled tight behind.'),
 ('Domeleon','reared up tall on its back legs and tail, its telescope cannon aimed high at the sky, frill spread wide, imposing.'),
 ('Zippelith','slithering fast in a big S-curve across the image, its zipper half open in a toothy grin.'),
 ('Skateron','in a low speed-skating crouch, neck stretched far forward, wings swept back tight like a speed suit, one blade lifted mid-stroke.'),
 ('Briarlynx','rearing up on its hind legs with thorny forepaws raised to strike, briar whip tail lashing, snarling.'),
 ('Howlop','lunging forward mid-howl with its huge ears flared wide and sound rings bursting from its open mouth.'),
 ('Dreadnoyak','charging head-down straight toward the viewer, ice keel forward, frost hair streaming back.'),
 ('Morelossus','reared up on its hind legs trumpeting, front feet high in the air, morel back towering.'),
 ('Lodestaff','reared up tall like a praying mantis with its lodestone forelegs raised and crossed, magnetic flakes orbiting.'),
 ('Blastopuff','fully inflated into a round ball about to burst, spikes out, fuse sparking, glaring.')]:
    _RP2(_n,_p)
