# Next steps after round 31 s18 (02:15 ET): Driftpup (sea-glass otter, Claude's pick) and owner-tier concepts get turnarounds;
# Glassolotl (rock candy) gets its turnaround and rock-candy concepts for its finals; Prismander male turnaround retried.
_O='briefs/boki-art/batch/out/'
TA('Driftpup','briefs/boki-art/concepts/Driftpup.jpg')
TA('Glassolotl',_O+'c_glassolotl_a_2.jpg'); SPECS[-1]['id']='ta_glassolotl_a'
TA('Bucketmander',_O+'c_bucketmander_w31_3.jpg'); SPECS[-1]['id']='ta_bucketmander_v'
TA('Fanpire',_O+'c_fanpire_w31_4.jpg')
TA('Fawngus',_O+'c_fawngus_n_1.jpg'); SPECS[-1]['id']='ta_fawngus_n'
TA('Prismander','briefs/boki-art/concepts/Prismander.jpg'); SPECS[-1]['id']='ta_prismander_a2'; SPECS[-1]['runs']=4
SPECS[-1]['prompt']+=" It stays low on all four legs in every view exactly like image 1, never standing upright; exactly one row of four, no repeated rows."
_GA=_O+'c_glassolotl_a_2.jpg'
VC('chandelotl_a','Chandelotl',_GA,'final',
 "A big, elegant rock-candy axolotl rearing up high on its front legs, its body glossy translucent hard candy, its gills grown into a tall crown of hanging sugar-crystal drops like a candy chandelier, one candy-cane stripe spiralling down its long tail. One clear idea, few parts.",
 "calm, proud glossy eyes and a gentle smile","strawberry pink and clear sugar white, with a mint-green and gold accent",
 "a real chandelier, candles, chains, sharp crystal spikes everywhere, rainbow effects, a busy design",'prism','majestic')
VC('geodelotl_a','Geodelotl',_GA,'final',
 "A huge, heavy rock-candy axolotl braced wide and low on thick legs, its back a thick crust of chunky rock-candy sugar crystals like a geode cracked open, the rest of its body glossy boiled sweet, and its tail ending in a big round crystallised sugar lump like a club. One clear idea, few parts.",
 "stubborn, steady glossy eyes and a confident grin","strawberry pink and sugar white, with a deep raspberry and mint accent",
 "grey stone, real rocks, armour plates, rainbow effects, a busy design",'prism','tough')
PRIORITY=['ta_prismander_a2','ta_glassolotl_a','c_chandelotl_a','c_geodelotl_a','ta_driftpup','ta_bucketmander_v','ta_fanpire','ta_fawngus_n']+PRIORITY
