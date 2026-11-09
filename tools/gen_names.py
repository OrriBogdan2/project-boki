import random, re
random.seed(7)
# cute words: nature, food, small things, weather, gems, music, cosy stuff
words = """Pip Mochi Bramble Sorrel Tumble Fig Juniper Biscuit Nettle Wren Sprout Ember Clove Pebble Marlo Quill Dusk Taffy Rune Kip
Acorn Alder Almond Amber Anise Apple Apricot Aster Azure Bamboo Barley Basil Bean Berry Birch Blossom Bluebell Bonbon Bracken Briar Brook Bubble Bun Burdock Butter Button
Cactus Cairn Calico Candle Caper Caramel Cardamom Cashew Cedar Celery Chai Chestnut Chicory Cinder Cinnamon Citrus Clover Cobble Cocoa Comet Copper Coral Cosmo Cotton Crumb Crumpet Cumin Cupcake Currant
Daisy Dandelion Date Dewdrop Dill Dimple Doodle Drizzle Dumpling Echo Elderberry Elm Fennel Fern Fernando Flint Flurry Fudge Gingko Ginger Glimmer Gnocchi Gooseberry Gravel Guava Gumdrop
Hazel Heather Hickory Holly Honey Hopscotch Huckle Indigo Ivy Jasper Jellybean Jinx Jolly Kale Kelp Kiwi Kumquat Larkspur Lavender Leek Lemon Lentil Lichen Lilac Lime Linden Lotus Lychee
Macaron Mallow Mango Maple Marigold Marzipan Meadow Melon Mint Miso Moss Muffin Mulberry Mustard Myrtle Nectar Nimbus Noodle Nougat Nutmeg Oak Oat Olive Onyx Orchid Oregano Otter
Paprika Parsley Peach Peanut Pear Pecan Pepper Persimmon Petal Pickle Pine Pinecone Pistachio Plum Poppy Porridge Pretzel Primrose Puddle Pumpkin Quince Radish Raisin Rain Raspberry Reed Rhubarb Ripple Rosehip Rowan Rye
Saffron Sage Salt Sapling Scone Sesame Shale Shallot Sherbet Shortcake Slate Sleet Snap Snowdrop Sorbet Spark Speck Spruce Squash Star Strudel Sugar Sumac Sundew Sunny Swirl
Tamarind Tansy Tapioca Teacup Thimble Thistle Thyme Toast Toffee Truffle Tulip Turnip Twig Twinkle Umber Vanilla Velvet Waffle Walnut Wasabi Willow Wisp Yarrow Yam Yuzu Zest Zinnia""".split()
on = ["b","p","m","f","t","d","n","l","k","g","s","z","w","r","ch","sh","pl","bl","fl","gl","sn","tr","br","dr","fr","gr","kr","sk","sp","st","tw","qu","v","j","h"]
nu = ["a","e","i","o","u","a","i","o","oo","ee","ai","ou"]
co = ["","","n","m","l","r","p","b","ck","ff","ll","pp","bb","zz","nk","mp"]
end = ["y","ie","o","a","i","et","in","le","ble","kin","bit","bo","ly","ny","by","sy","zy","bun","bean","dot","nip","puff","let","kins","pip","sprout","bell","drop","wick","moss","berry","fern","plum","cake","bun"]
s1on = ["b","p","m","f","t","d","n","l","k","g","s","z","w","r","j","h","ch","v"]
s1nu = ["a","e","i","o","u"]
bad = re.compile(r"(fuk|fuc|fack|fak|phuc|jingo|iy$|uy$|shit|cum|dic|dik|cock|cok|tit|nig|fag|gay|sex|ass|arse|piss|poo|pee|rape|kkk|nazi|jew|hoe|slut|whor|cunt|twat|wank|butt|boob|dum|kil|die|dead|anal|anus|hell|damn|crap|turd|porn|kun|fap|homo|negr|spic|chin|gook|kike|retard|bitch|tard)", re.I)
def syl():
    return random.choice(on)+random.choice(nu)+random.choice(co)
kin=set(words)
while len(kin)<2200:
    r = random.random()
    if r < 0.55: n = syl()+random.choice(end)
    elif r < 0.85: n = random.choice(on)+random.choice(nu)+random.choice(["","n","m","l","r"])+random.choice(s1on)+random.choice(s1nu)+random.choice(["","","y","n","l"])
    else: n = random.choice(on)+random.choice(nu)+random.choice(co)
    if re.search(r"(ck|ff|ll|pp|bb|zz|nk|mp)[^aeiouy]", n): continue
    n = n[:1].upper()+n[1:]
    if re.search(r"[^aeiouy]{3}", n.lower()): continue
    if 3<=len(n)<=8 and not bad.search(n) and not re.search(r"(.)\1\1",n) and not re.search(r"[aeiou]{3}",n): kin.add(n)
kin = sorted(kin, key=lambda s:(s not in words, random.random()))[:2200]
# bot names: sharp gamer-ish handles
bon = ["v","k","r","z","t","s","n","m","j","b","d","c","l","dr","kr","tr","sk","st","th","br","gr","vr","w","f","h","x"]
bnu = ["a","e","i","o","u","a","e","i","o","ae","ai","io"]
bco = ["","n","x","r","k","l","s","th","sh","z","v","nn","rr","ss","ck","rn","nt","st","lk","sk","x","rd","ld","m"]
bend = ["","a","o","is","us","ix","yn","en","ar","or","el","ia","ra","ka","on","ex","ax","ek","ir","ys","ie","ri","ne","ze","ka"]
bwords = """Vexa Moss Tarn Juno Rook Kestrel Nim Sable Orin Lux Bryn Cato Ivy Rho Wick Zed Fen Mara
Ash Blaze Bolt Briar Cinder Cobalt Crow Dagger Drift Echo Ember Flint Frost Gale Ghost Grim Hawk Hex Hollow Jinx Jolt Kite Lynx Mako Nova Onyx Pike Quill Raven Reef Riot Rust Scythe Shade Slate Spike Storm Talon Thorn Vale Viper Volt Warden Wraith Zephyr""".split()
bot=set(bwords)
while len(bot)<2000:
    n = random.choice(bon)+random.choice(bnu)+random.choice(bco)+random.choice(bend)
    n = n[:1].upper()+n[1:]
    if re.search(r"[^aeiouy]{3}", n) or re.search(r"[aeiou]{3}", n): continue
    if 3<=len(n)<=7 and not bad.search(n) and not re.search(r"(.)\1\1",n) and n not in kin: bot.add(n)
bot = sorted(bot, key=lambda s:(s not in bwords, random.random()))[:2000]
def arr(a):
    out=[];line="\t"
    for x in a:
        t='"%s", '%x
        if len(line)+len(t)>110: out.append(line.rstrip()); line="\t"
        line+=t
    out.append(line.rstrip().rstrip(","))
    return "[\n"+"\n".join(out)+"\n]"
src = "class_name Names\n## Name pools for kin and bot hunters: a few hundred hand-picked words plus generated ones\n## (pronounceable, filtered for anything rude), so the same name rarely comes up twice.\n## Regenerate with tools/gen_names.py.\n\nconst KIN := " + arr(kin) + "\n\nconst BOT := " + arr(bot) + "\n"
open(__import__("os").path.join(__import__("os").path.dirname(__file__), "..", "scripts", "core", "names.gd"),"w").write(src)
print(len(kin),len(bot), random.sample(kin[300:],25), random.sample(bot[80:],25))
