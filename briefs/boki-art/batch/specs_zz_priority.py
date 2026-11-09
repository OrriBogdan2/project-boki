# Round 10 (21:12 ET 11-08): coordinator INBOX_IMG 2026-11-09, 3 owner redos (bar 8.5), priority over new species.
# Sporcupine 7.9: mushrooms too tall/odd -> short spiky quill-like caps hugging the body. Voltmink 7.0: calm, cool, relaxed pose.
# Teapotamus 7.1: already redone as teapotamus_r2 / teapotamus_r2b (wave 7); moved to the front of the queue here.
_EDIT=("Edit image 1: keep the same creature, the same design, colours, markings, face and style, the same four views in one row "
       "and the same plain pale grey background. Only change this: ")
SPECS.append({'id':'sporcupine_r','name':'Sporcupine (owner redo)','refs':[E+'Sporcupine.jpg',SR3],'runs':3,'prompt':_EDIT+
 "replace the tall mushrooms on its back with many short, spiky mushroom caps shaped like porcupine quills: small pointed caps on short "
 "stems that sit close to the body, lean backwards and follow the rounded porcupine silhouette like a coat of quills, getting a little "
 "longer toward the rump. No tall stalks, nothing sticking straight up, nothing taller than its head. Keep it on all four legs in every view. "
 "Do not add anything else."})
SPECS.append({'id':'voltmink_r','name':'Voltmink (owner redo)','refs':[E+'Voltmink.jpg',SR3],'runs':3,'prompt':_EDIT+
 "make it look calm and cool: a relaxed, easy stance on all four legs with its body loose and its tail curling lazily, its head held level, "
 "half-lidded, confident eyes and a small, self-assured smirk, and its electricity reduced to a few calm, slow sparks along its fur instead of "
 "crackling bolts. Not tense, not crouching, not snarling or aggressive. Do not add anything else."})
PRIORITY=['sporcupine_r','voltmink_r','teapotamus_r2','teapotamus_r2b']
