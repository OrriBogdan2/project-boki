# 05:40 ET 11-09 tick. Glassolotl (owner: different face AND angle/pose from Prismander): g1_1 picked on eye check
# (right-facing mid-leap, new grinning face, long body that leads into the cobra Chandelotl). Plus retries of failed sheets/portrait.
_O='briefs/boki-art/batch/out/'; _C='briefs/boki-art/cards/'
TA('Glassolotl',_O+'c_glassolotl_g1_1.jpg'); SPECS[-1]['id']='ta_glassolotl_p93'
SPECS.append({'id':'glassolotl_card93','name':'Glassolotl (hero card)','refs':[_O+'c_glassolotl_g1_1.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K','prompt':CARD('Glassolotl','mid','mid-leap facing right, legs stretched and body arched, cocky open grin')})
P('glassolotl_p93','Glassolotl',_O+'c_glassolotl_g1_1.jpg','mid-leap facing right, legs stretched and body arched, cocky open grin')
TA('Cisternmander',_C+'Cisternmander.jpg' if False else _O+'c_cisternmander_y2_1.jpg'); SPECS[-1]['id']='ta_cisternmander_r93'
TA('Flarmink',_O+'c_flarmink_m2_4.jpg'); SPECS[-1]['id']='ta_flarmink_r93'
TA('Prismink',_O+'c_prismink_m3_3.jpg'); SPECS[-1]['id']='ta_prismink_r93'
TA('Crofthollow',_C+'Crofthollow.jpg'); SPECS[-1]['id']='ta_crofthollow_r93'
P('eclipsowl_r93','Eclipsowl',_C+'Eclipsowl.jpg','in the same pose and look as its hero card')
