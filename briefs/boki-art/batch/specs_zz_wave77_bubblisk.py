# Owner 03:43 ET 11-09: "bubblisk is cute but it either needs 1 evolution only or a lot of distinction on its next two".
# Art session call: 2-stage line Bubblisk > Tidalisk; Frothisk is cut. Tidalisk becomes a big, clearly different final.
_P77=[]
_AVT2="the same lizard body as image 1 made bigger, standing upright like a person, a rider, a busy design"
for _k,_b in (('t1',"A huge sea-serpent basilisk rearing high out of a curling ocean wave that forms its own lower body, a great frilled crest like breaking surf, pearly iridescent scales, and a long whip tail of sea foam."),
              ('t2',"A massive tidal dragon-lizard braced wide on four powerful legs, a tall sail fin along its back shaped like a cresting wave with foam at the tip, heavy armoured pearly scales, and huge bubble-filled cheek pouches."),
              ('t3',"A colossal bubble leviathan lizard with a broad crowned head, a back covered in big glassy iridescent bubble domes like armour, long fin-frills sweeping from its jaw, and a heavy finned tail, looming and planted."),
              ('t4',"A giant storm-surf basilisk running on its hind legs across water at speed, huge webbed feet throwing spray, a towering crest and dorsal frill like a sail, and a long rudder tail, sleek and powerful."),
              ('t5',"A huge, regal pearl-shell basilisk lying coiled like a sea dragon, its body ringed with nacre plates, a crown of shell spikes, a frilled ruff of foam, and a giant pearl bubble glowing in its chest.")):
    VC('tidalisk_'+_k,'Tidalisk','briefs/boki-art/cards/Bubblisk.jpg','final',_b+" A huge, high-impact final, very different from image 1. One clear idea, few parts.","fierce, gleaming sea-green eyes and a proud snarl","pearly lilac and ocean blue, with an iridescent foam-white accent",_AVT2,'tide','majestic'); _P77.append('c_tidalisk_'+_k)
PRIORITY=_P77+PRIORITY
