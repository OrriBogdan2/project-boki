# Owner 01:42 ET 11-09: Vespyx is super cute but should match the other cards (positioning); same for Mycroll; both need turnarounds
# (their turnarounds exist: turnarounds/Vespyx.jpg, turnarounds/Mycroll.jpg, re-posed 01:20). New canon hero cards for both,
# made from the original starter art so the cuteness is kept, framed exactly like the rest of the card set.
_FR=(" Match the framing of the whole Boki card set exactly: the same gentle three-quarter view, the creature centred and filling about"
     " 84 percent of the square at the same scale as the other cards, feet on an invisible floor line in the lower fifth, no shadow, no glow.")
for _n,_src,_pose in [('Vespyx','briefs/boki-art/turnarounds/Vespyx_old_stance.jpg','sitting curled up like a pup with its scorpion tail curved over its back and one paw lifted, head tilted toward the viewer'),
                      ('Mycroll','briefs/boki-art/turnarounds/Mycroll_old_stance.jpg','sitting round and bouncy with its mushroom quills puffed up, head tilted toward the viewer')]:
    SPECS.append({'id':_n.lower()+'_card3','name':_n+' (hero card)','refs':[_src,SRA],'runs':4,'aspect':'1:1','size':'2K','prompt':CARD(_n,'baby',_pose)+_FR})
PRIORITY=['vespyx_card3','mycroll_card3']+PRIORITY
