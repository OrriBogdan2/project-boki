# Owner 01:32 ET 11-09: the ink-pool design that was "Umbrink" is its own line (Blotlet > Slog > Sloggoth). Umbrink is redone as a
# real Ink-family mink in the original direction ("soaked jet-black, smoking brush"), with its own stance.
_SL='briefs/boki-art/evolutions/Slog.jpg'
SPECS[:]=[s for s in SPECS if s['id']!='c_blotlet']; CQ('Blotlet',_SL)
CQ('Sloggoth',_SL); SPECS[-1]['id']='c_sloggoth'
_INK3=(" It is a grown-up Ink form: clearly bigger than image 1 (about twice its size), longer and stronger, and the same stoat species as image 1 (Ermink's"
       " face mask shape, brush tail and ink markings), never a blob, a pool or a ghost.")
VC('umbrink_n','Umbrink',E+'Ermink.jpg','final',
 "A long, sleek stoat whose fur is soaked jet-black ink, glossy and dripping at the edges, slinking low through shadow with its body stretched long, head low and forward, one forepaw raised mid-step, and its long brush tail held up behind it smoking: thin curls of dark violet smoke rise from the brush tip like incense."+_INK3,
 "narrow, glowing violet eyes and a sly, knowing smile","ink black and deep purple, with a violet smoke accent",
 "a pool, a blob, tentacles, standing upright, sitting like a cat, a ghost",'shadow','sleek')
PRIORITY=['c_umbrink_n','c_blotlet','c_sloggoth']+PRIORITY
