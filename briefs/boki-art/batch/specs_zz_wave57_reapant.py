# Owner 03:15 ET 11-09: "reapant should be like a bug ninja ... more ninja like, instead of just a slightly bigger [Scythant]".
# Owner un-locks Reapant (removed from owner_locked sheet list). Final of Marchleaf > Scythant > Reapant (leaf ants, Swarm).
# Five directions; all stay an ant on six legs (never upright, never a mantis copy), with an original ninja read built from body
# parts only: mask markings, blade forelimbs, a leaf-frond 'scarf', a lean silent crouch. Nothing worn or held.
_MR='briefs/boki-art/'+next(d for d in ('turnarounds','evolutions') if (HERE.parent/d/'Marchleaf.jpg').exists())+'/Marchleaf.jpg'
_AVR="standing upright, a mantis, a person, clothes, a cloth mask, a headband, held swords or weapons, shuriken, smoke bombs, effects, a busy design, a queen ant, a crown"
_P57=[]
for _k,_b,_f,_c in (
 ('n1',"A lean leaf-ant ninja crouched low and silent on six thin legs, ready to spring: its two front legs grown into long folded leaf-blade scythes held back along its body, a dark bark-brown band across its eyes like a ninja mask, and a long tattered leaf-frond growing from the back of its neck and trailing behind like a scarf.",
  "narrow, focused compound eyes peering out of the dark mask band","leaf green and dark bark brown, with a lime accent"),
 ('n2',"A shadow leaf-ant ninja frozen mid-dash, low to the ground on six legs with its body stretched long and sleek, its mandibles grown into two slim crossed leaf-blades in front of its face, a dark mask marking over its eyes, thin fern antennae swept straight back by speed.",
  "sharp, calm compound eyes over the crossed blades","dark forest green and night brown, with a lime accent"),
 ('n3',"A silent assassin ant perched in a ninja crouch on six legs, head low and turned toward the viewer, its slim armoured body dark like a shadow, two forelegs ending in long curved leaf-blade sickles held low and ready, and a split leaf-blade tail-tip behind it.",
  "cold, glinting lime compound eyes and a hidden smirk","near-black green and bark brown, with a sharp lime edge on every blade"),
 ('n4',"An elegant leaf-ant ninja balanced on four back legs and two blade forelegs in a wide low ready stance, its body wrapped in overlapping dark leaf plates like layered shinobi armour (grown, not worn), a long leaf-frond scarf from its neck, and slim fern antennae swept back.",
  "focused, serious compound eyes in a dark mask","leaf green and charcoal bark, with a lime accent"),
 ('n5',"A fast ninja ant leaping low across the ground on six legs, mid-stride and nearly flat, two leaf-blade forearms tucked back like sheathed swords along its sides, a dark eye-mask marking and two long leaf-frond ribbons streaming from its neck.",
  "intense, playful compound eyes and a cocky grin","bright leaf green and dark bark, with a lime accent")):
    VC('reapant_'+_k,'Reapant',_MR,'final',_b+" A big step up from a soldier ant: lean, fast and deadly, clearly a ninja at a glance. One clear idea, few parts.",_f,_c,_AVR,'swarm','fast')
    _P57.append('c_reapant_'+_k)
PRIORITY=_P57+PRIORITY
