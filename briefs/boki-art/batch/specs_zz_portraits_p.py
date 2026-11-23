# Pokedex-style hero portraits for every Boki that stays (owner 22:15: "a lot of the ones in the dex look bad").
# Uses the current P() prompt (Pokedex framing, simple characteristic pose, no effects). Boki being redesigned are skipped;
# they get portraits when their new sheet passes.
import json as _j
for _n,_tag,_f in _j.load(open(HERE/'portrait_keep.json')):
    P(_n.lower()+'_p',_n,(T if _tag=='T' else E)+_f,'in its most characteristic, lively pose, showing off its signature part')
    SPECS[-1]['aspect']='1:1'
