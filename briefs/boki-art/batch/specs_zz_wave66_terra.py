# Owner 03:36 ET 11-09: "lets change terrasloth to a different animal - not a monkey but something we aren't using now" (the
# Umbrathere line is already a sloth). Keep the greenhouse idea (glass panes in white iron frames with plants growing inside), on
# five animals not in the roster. Single-stage Boki; name changes with the pick.
_TS='briefs/boki-art/cards/Terrasloth.jpg'; _P66=[]
_AVT="a sloth, a monkey, a building it sits in, a separate greenhouse it carries, standing upright, a busy design"
for _k,_a,_b in (
 ('t1','tortoise',"A big, gentle tortoise whose shell is a domed glass greenhouse of curved panes in white iron frames grown into its body, lush plants and tiny flowers growing inside, mossy legs, walking slowly forward."),
 ('t2','snail',"A large, chubby land snail whose spiral shell is a glass conservatory of curved panes in white iron frames, ferns and flowers growing inside the spiral, its soft green body gliding forward with two curious eye stalks."),
 ('t3','hermit crab',"A plump hermit crab living in a round glass terrarium-jar shell framed in white iron, a tiny garden of moss and plants growing inside it, its big friendly claws held forward."),
 ('t4','pangolin',"A round pangolin whose scales are small glass greenhouse panes in white iron frames, tiny plants and seedlings growing behind each pane, curling its long tail around itself."),
 ('t5','koala',"A sleepy, round koala with a small glass greenhouse dome grown into its back in white iron frames, eucalyptus leaves and flowers growing inside, sitting hugged up with a vine trailing from its arms.")):
    VC('terrasloth_'+_k,'Terrasloth',_TS,'redo_of',"Same greenhouse idea and palette as image 1, but the creature is now a "+_a+", not a sloth. "+_b+" One clear idea, few parts.","soft, sleepy green eyes and a gentle smile","moss green and glass white, with a soft flower-pink accent",_AVT,'bloom','cute'); _P66.append('c_terrasloth_'+_k)
PRIORITY=_P66+PRIORITY
