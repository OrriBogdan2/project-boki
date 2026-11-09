# Bokidex portraits: one per approved sheet, made from that sheet.
def P(i, name, ref, pose):
    SPECS.append({'id': 'portrait_' + i, 'name': name + ' (portrait)', 'refs': [ref], 'aspect': '1:1', 'runs': 2,
      'prompt': ("Official creature-collector encyclopedia portrait of the exact creature in image 1, for a fantasy action game. "
        "Keep its design exactly as in image 1: the same body, colours, markings, face, eyes and every detail, nothing added or removed. "
        "Show it once, full body, in a lively three-quarter view with a little attitude that fits its personality: " + pose + ". "
        "Centered, the whole body in frame with a little space around it, filling most of the square. "
        "Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, not realistic. "
        "Plain soft light background in a pale tint of its main colour with a gentle vignette, a soft contact shadow under it, "
        "no scenery, no other creatures, no text, no frame, no turnaround views.")})
P('chuggamus', 'Chuggamus', T + 'Chuggamus.jpg', 'charging forward with steam blasting from its nostrils and its firebox blazing')
P('vespox', 'Vespox', E + 'Vespox.jpg', 'crouched low and ready to pounce, tail sting raised and one pincer snapping')
P('lanternmit', 'Lanternmit', E + 'Lanternmit.jpg', 'peeking proudly from its glowing lantern shell with its big claw raised')
P('stormit', 'Stormit', E + 'Stormit.jpg', 'scuttling sideways in a jittery panic with sparks jumping off its claws')
