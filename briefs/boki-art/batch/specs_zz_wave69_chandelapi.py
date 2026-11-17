# Owner 03:37 ET 11-09: "chandelapi is so busy and needs to be majestic without looking rigid and crowded". Keep the idea
# (okapi final of Wickapi > Snuffapi > Chandelapi, candle antlers, violet flames) but strip it back: few big shapes, no gold filigree
# over the body, a graceful flowing pose instead of a stiff stand.
_CP='briefs/boki-art/cards/Chandelapi.jpg'; _P69=[]
_AVC="gold filigree or vines over the body, more than six candles, candles on the tail, spikes, a stiff side-on stand, a chandelier, a busy design"
for _k,_b in (
 ('m1',"A tall, graceful okapi stag in mid-stride with its head raised proudly, two sweeping antlers like smooth curved brass candelabra arms holding just three tall violet-flame candles each, clean dark-chestnut fur with crisp white okapi stripes on its legs, a long elegant neck."),
 ('m2',"A majestic okapi with a calm, regal head turned toward the viewer, a single simple crown of smooth antlers that curve up into four slim candles with soft violet flames, a flowing wax-drip mane down its neck, and bold okapi leg stripes, stepping forward lightly."),
 ('m3',"A serene okapi elder standing tall and relaxed, one foreleg lifted, its antlers two simple elegant branches ending in a single large violet-flame candle each, melted wax forming soft pale patterns on its shoulders, clean silhouette with lots of breathing room."),
 ('m4',"A noble okapi caught in a slow, graceful turn, long neck curved, broad smooth antlers shaped like a candelabra crown with five small violet flames in a gentle arc, its tail ending in a single soft wisp of violet flame, simple dark fur and white leg stripes.")):
    VC('chandelapi_'+_k,'Chandelapi',_CP,'redo_of',"Same creature and idea as image 1 but simplified and more majestic: "+_b+" Few big shapes, clean silhouette, relaxed and flowing. One clear idea, few parts.","gentle, wise violet eyes and a calm, regal look","dark chestnut brown and soft cream, with brass and violet-flame accents",_AVC,'ember','majestic'); _P69.append('c_chandelapi_'+_k)
PRIORITY=_P69+PRIORITY
