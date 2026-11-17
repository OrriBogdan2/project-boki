# Owner 03:36 ET 11-09: "lanceron and skateron are too close" (both slim grey ice herons). Lanceron (final of Skidlet > Skateron >
# Lanceron) gets five finals that change the body plan; ice skates/blades and the lance idea stay.
_SK='briefs/boki-art/turnarounds/Skateron.jpg'; _P67=[]
_AVN="a slim heron like image 1, the same pose as image 1, standing upright like a person, a rider, held weapons, a busy design"
for _k,_b in (
 ('k1',"A huge, heavy ice-knight crane braced wide and low like a charging jouster: a broad armoured chest of thick ice plates, its long beak grown into a great spiral ice lance pointed forward, short powerful legs ending in big blade skates, wings folded like a shield."),
 ('k2',"A giant ice-lance heron-dragon: a long serpentine neck, a big horned head with a lance-like ice beak, broad frozen crystal wings spread wide, a long tail of icicle feathers, and four strong taloned legs with blade skates, planted and towering."),
 ('k3',"A towering frost guardian bird with a huge puffed chest of white frost feathers, a tall crown of ice spikes, wings that end in long curved ice-blade primaries like swords, standing planted on thick legs with wide skate blades."),
 ('k4',"A massive armoured ice stork-rhino: a heavy rounded body plated in ice, a short thick neck, its beak a huge forward-thrusting ice lance with a horn, small stubby wings, and chunky legs with blade skates, lowered into a charge."),
 ('k5',"A grand winter-knight heron rearing tall with wings flung open like a cape of icicles, a visor-like ice crest over its eyes, a long lance beak, and its legs and toes encased in big curved skate blades, the whole body much bulkier and broader than image 1.")):
    VC('lanceron_'+_k,'Lanceron',_SK,'final',_b+" Clearly a different body plan from image 1. One clear idea, few parts.","cold, proud ice-blue eyes and a stern look","frost white and slate blue-grey, with an ice-cyan accent",_AVN,'frost','tough'); _P67.append('c_lanceron_'+_k)
PRIORITY=_P67+PRIORITY
