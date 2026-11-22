# Owner 22:45: starter portraits are on black, the rest on light grey. Main Bokidex style = light. Re-make the two
# owner-approved starter shots on the light background, keeping the art identical; the dark originals stay as alt art.
for _n in ('vespyx','mycroll'):
    SPECS.append({'id':'portrait_'+_n+'_light','name':_n.capitalize()+' (portrait, light)','refs':['briefs/boki-art/style_refs/'+_n+'_2d_ref.png'],
      'runs':2,'aspect':'1:1','prompt':"Edit image 1: keep the creature exactly the same, the same pose, design, colours, lighting on the creature and every detail. "
      "Only change the background: replace the dark background and dark glow with a plain flat very light grey background, with no shadow and no vignette. "
      "Keep the creature centred and filling about 85 percent of the square, nothing cut off."})
PRIORITY=['portrait_vespyx_light','portrait_mycroll_light']+PRIORITY
