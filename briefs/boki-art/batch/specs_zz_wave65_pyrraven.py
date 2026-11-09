# Owner 03:35 ET 11-09: "make pyrraven embrook and make a bigger more demonic bird for their t3". The old Pyrraven art is now
# Embrook's (t2, owner-locked); Pyrraven (t3) gets new, much bigger, demonic fire-bird finals. Owner un-locks Pyrraven.
_EB='briefs/boki-art/evolutions/Embrook.jpg'; _P65=[]
_AVP="the same raven body as image 1 made bigger, a person, standing upright like a human, gore, skulls, held objects, a busy design"
for _k,_b,_f in (
 ('d1',"A huge demonic fire raven looming with its great wings half-raised like a cloak, two curved black horns sweeping back from its brow, a mane of black flame-feathers, molten cracks glowing across its chest, and long talons gripping the ground.","burning, narrowed molten-orange eyes and a cruel hooked-beak smirk"),
 ('d2',"A towering infernal bird with four wings spread in a wide fan, its feathers like charred obsidian blades edged in fire, a crown of three horns, a long whip-like tail of embers, planted on thick taloned legs.","blazing white-hot eyes with no pupils and an open, screaming beak"),
 ('d3',"A massive hunched hellfire vulture-raven with a bare, bony horned head, a heavy ruff of black flaming feathers around its neck, broad molten-cracked wings folded like a shroud, perched on huge talons.","sunken, glowing ember eyes and a grim, patient stare"),
 ('d4',"A giant demon phoenix-crow rearing tall with wings flung wide, its body charred black stone with lava running in the cracks, ram-like curled horns, a long jagged tail of black flames, and a halo-ring of fire behind its head.","fierce burning eyes and a wide, triumphant beak"),
 ('d5',"A huge armoured fire raven with a beak like a black blade, a crest of jagged horn-feathers, heavy obsidian plates over its chest and wings, molten light glowing between the plates, braced low and wide like it is about to lunge.","narrow, furious orange eyes"),
 ('d6',"An enormous three-eyed demonic raven with a long neck and a tall crest of flickering black fire, ragged smoky-flame wings spread low around it like a cape, glowing rune-like cracks on its wings, standing planted and looming over the viewer.","three glowing molten eyes and a sly, sinister smile"),
 ):
    VC('pyrraven_'+_k,'Pyrraven',_EB,'final',_b+" Much bigger and more menacing than image 1, clearly demonic but still a stylised creature-collector design. One clear idea, few parts.",_f,"charcoal black and molten orange, with a white-hot accent",_AVP,'ember','tough'); _P65.append('c_pyrraven_'+_k)
PRIORITY=_P65+PRIORITY
