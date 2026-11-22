# Owner 03:14 ET 11-09. (1) Umbrink: the old ink-pool design is now Slog's line; Umbrink must be a real mink branch of Ermink again.
# The 01:50 attempt (c_umbrink_n, 7.8) read as a plain black stoat that looked like Slog and copied Rimink/Voltmink stances.
# Three directions, each with an ivory mask/belly (Slog is all black), a big stylised head, an ink-brush identity and its own stance.
_EM='briefs/boki-art/evolutions/Ermink.jpg' if (HERE.parent/'evolutions'/'Ermink.jpg').exists() else 'briefs/boki-art/turnarounds/Ermink.jpg'
_AVU="a pool, a puddle, a blob, tentacles, dripping all over, smoke clouds, standing upright, coiling like a snake, an all-black body, a ghost, held brushes or objects"
_P56=[]
for _k,_b,_f in (
 ('u1',"A sleek calligrapher Ermink evolution: deep indigo-ink fur fading to an ivory mask over its eyes and an ivory chest, its tail ending in a big soft calligraphy-brush tip wet with ink, crouched wide and planted with both front paws spread on the ground and its rear raised, tail arched high over its back mid-stroke, a single ink drop hanging from the brush tip.",
  "big sly violet eyes in the ivory mask and a clever closed-mouth smile"),
 ('u2',"A proud ink-wash: its fur painted in bold sumi-ink brushstrokes, dark indigo on the back washing to soft grey and ivory on the belly and face, with brushstroke-shaped fur edges, standing planted square on all four legs with its chest out and big head lifted, its long brush tail swept around its feet in one confident curved stroke.",
  "calm, knowing violet eyes and a small proud smile"),
 ('u3',"A shadow-ink: long and lithe with a big stylised head, dark indigo-ink fur with an ivory face mask and ivory paws, brushstroke markings like calligraphy along its flanks, planted low in a ready stance looking back over its shoulder at the viewer, its brush tail raised in an S-curve with a thin wisp of violet smoke curling from the tip.",
  "narrow, playful violet eyes and a sly sideways grin")):
    VC('umbrink_'+_k,'Umbrink',_EM,'final',_b+" Clearly the same species as image 1, grown up, and clearly different from an all-black stoat made of ink. One clear idea, few parts.",_f,
       "deep indigo ink and ivory, with a violet accent",_AVU,'shadow','sleek'); _P56.append('c_umbrink_'+_k)
# (2) Vespyx: every turnaround so far kept the source's dark gradient floor, so it doesn't sit with the other sheets. New turnaround
# from the clean live hero card, on the standard flat background.
TA('Vespyx','briefs/boki-art/cards/Vespyx.jpg'); SPECS[-1]['id']='ta_vespyx_flat'; SPECS[-1]['runs']=4
SPECS[-1]['prompt']+=" Plain flat pale grey background exactly like every other sheet: no floor, no ground line, no gradient, no dark vignette, no shadow, no glow."
_P56.append('ta_vespyx_flat')
PRIORITY=_P56+PRIORITY
