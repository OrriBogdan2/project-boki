# Bokidex portraits: one per approved sheet, made from that sheet.
def P(i, name, ref, pose):
    SPECS.append({'id': 'portrait_' + i, 'name': name + ' (portrait)', 'refs': [ref], 'aspect': '1:1', 'runs': 3,
      'prompt': ("Official creature-collector encyclopedia portrait of the exact creature in image 1, for a fantasy action game. "
        "Keep its design exactly as in image 1: the same body, colours, markings, face, eyes and every detail, nothing added or removed. "
        "Show it once, full body, in an interesting, characteristic pose full of personality and attitude, like official creature-encyclopedia art (never a stiff side-on standing pose): " + pose + ". "
        "A natural three-quarter view at eye level with a clear, readable silhouette and a little movement in the body, its head turned slightly so it looks off to the side, not straight at the camera, not a straight front view. "
        "No effects at all: no sparks, petals, embers, smoke, glow bursts or motion lines. "
        "Framed like an official creature-encyclopedia entry: the creature is centred and big, filling about 85 percent of the square, with only a thin margin around it and nothing cut off. "
        "Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, not realistic. "
        "Plain flat white background, no shadow, no vignette, no scenery, no other creatures, no text, no frame, no turnaround views.")})
P('chuggamus', 'Chuggamus', T + 'Chuggamus.jpg', 'charging forward with steam blasting from its nostrils and its firebox blazing')
P('vespox', 'Vespox', E + 'Vespox.jpg', 'crouched low and ready to pounce, tail sting raised and one pincer snapping')
P('lanternmit', 'Lanternmit', E + 'Lanternmit.jpg', 'peeking proudly from its glowing lantern shell with its big claw raised')
P('stormit', 'Stormit', E + 'Stormit.jpg', 'scuttling sideways in a jittery panic with sparks jumping off its claws')
P('bubblisk', 'Bubblisk', T + 'Bubblisk.jpg', 'mid-pounce, blowing a big wobbly bubble with a sly grin')
P('lunowl', 'Lunowl', T + 'Lunowl.jpg', 'swooping silently down past the moon with its moth wings spread wide')
P('murmurling','Murmurling',T+'Murmurling.jpg','mid-song with its pipe tail fanned and music notes rising')
P('oarlet','Oarlet',E+'Oarlet.jpg','paddling forward proudly with its paddle tail raised')
P('amanitusk','Amanitusk',E+'Amanitusk.jpg','charging head-down with toxic spores bursting from its caps')
P('anvilbrock','Anvilbrock',T+'Anvilbrock.jpg','braced to charge, hammer paws planted and stripe glowing')
P('blossmink','Blossmink',E+'Blossmink.jpg','prancing with petals swirling off its leaf-brush tail')
P('prismink','Prismink',E+'Prismink.jpg','bounding mid-air leaving a rainbow brushstroke behind it')
P('skidlet','Skidlet',E+'Skidlet.jpg','wobbling on one skate blade, wings out for balance')
P('lanceron','Lanceron',E+'Lanceron.jpg','striking forward with its ice-lance beak, blade wings flared')
P('seamwyrm','Seamwyrm',E+'Seamwyrm.jpg','rearing up with its zipper jaws wide open and glowing')
