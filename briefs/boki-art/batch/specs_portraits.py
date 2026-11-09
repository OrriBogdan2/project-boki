# Bokidex portraits: one per approved sheet, made from that sheet.
def P(i, name, ref, pose):
    SPECS.append({'id': 'portrait_' + i, 'name': name + ' (portrait)', 'refs': [ref], 'aspect': '1:1', 'runs': 2,
      'prompt': ("Official creature-collector encyclopedia portrait of the exact creature in image 1, for a fantasy action game. "
        "Keep its design exactly as in image 1: the same body, colours, markings, face, eyes and every detail, nothing added or removed. "
        "Show it once, full body, in a dynamic action pose caught mid-motion that shows off its signature part and personality: " + pose + ". "
        "Frame it like a striking hero shot for a creature encyclopedia: a dramatic three-quarter angle from slightly below, its body twisting through the frame with a strong diagonal line of action, "
        "its head turned to the side and its eyes looking at something off-frame, never looking at the camera, never a straight front view, never standing still. "
        "A touch of energy from its type around it (a few sparks, petals, droplets or embers), kept small. "
        "Centered, the whole body in frame with a little space around it, filling most of the square. "
        "Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, not realistic. "
        "Plain soft light background in a pale tint of its main colour with a gentle vignette, a soft contact shadow under it, "
        "no scenery, no other creatures, no text, no frame, no turnaround views.")})
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
