# Owner 03:43 ET 11-09: "buckleron should get an evo too" (shield limpet). Final above it, working name Bastionpet.
_P78=[]
for _k,_b in (('e1',"A huge armoured limpet-crab: its cone shell grown into a great layered tower shield with a big spike boss, stout crab legs planted wide underneath, two heavy shield-plate claws, and eye stalks peering over the rim."),
              ('e2',"A giant fortress limpet whose shell is a round castle-gate shield ringed with iron rivets and short spikes, the soft foot now a broad muscular base, two thick tentacle arms ending in small round buckler shields."),
              ('e3',"A massive limpet knight-tortoise: a tall domed iron shield shell with overlapping plates like a war helmet, stubby armoured legs, a heavy spiked boss crown on top, and a stern face peeking from under the visor rim."),
              ('e4',"A towering stacked limpet: three iron shield shells stacked in a spiked tower like a siege tower, the creature peering out from the bottom rim with eye stalks, braced on a wide clinging foot.")):
    VC('bastionpet_'+_k,'Bastionpet','briefs/boki-art/turnarounds/Buckleron.jpg','final',_b+" Clearly Buckleron's evolution, much bigger and tougher. One clear idea, few parts.","stubborn, grumpy little eyes on stalks","iron grey and rust, with a brass accent","a person, a held shield, standing upright, a busy design",'stone','tough'); _P78.append('c_bastionpet_'+_k)
PRIORITY=_P78+PRIORITY
