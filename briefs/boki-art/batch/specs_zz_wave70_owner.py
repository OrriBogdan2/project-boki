# Owner 03:38 ET 11-09: "a better anchorbill got lost for a worse one". The 01:42 promotion put anchorbill_r run 2 (owner: redo)
# live instead of the approved anchorbill run 1 (dark raven with an iron anchor beak). Run 1 restored as the sheet
# (turnarounds/Anchorbill.jpg); the r2 sheet kept as Anchorbill_lost_r2.jpg. Card and portrait were made from r2, so they are
# redone from the approved sheet.
_P70=[]
SPECS.append({'id':'anchorbill_card8','name':'Anchorbill (hero card)','refs':['briefs/boki-art/turnarounds/Anchorbill.jpg',SRA],'runs':3,'aspect':'1:1','size':'2K',
  'prompt':CARD('Anchorbill','mid','glaring with its heavy anchor beak lowered, wings half raised')}); _P70.append('anchorbill_card8')
P('anchorbill_fix','Anchorbill','briefs/boki-art/turnarounds/Anchorbill.jpg','glaring with its heavy anchor beak lowered, wings half raised'); _P70.append('portrait_anchorbill_fix')
PRIORITY=_P70+PRIORITY
