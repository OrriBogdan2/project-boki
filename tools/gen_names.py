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
# bot names: hand-written gamer tags (no hunter names or titles, nothing rude); unique per match
bot = """kyoto_drift nightjar Pixelpup zr0 BrewMaster tofu.exe lowbatt_ Mossback jetsam44 PaperTiger dustyboots
OatmealRaider quietstorm ctrl_alt_pie sk8rboi_ tinyvolt Wafflehaus ghostpepper_ nox FrostByte spoonfed gl1tchy
moonwalker99 Cr0ssfade zippy_z kettlecorn BigMood Lunchbreak st4rfish hotsauce_ reroll_ rustbucket
pancakes4all sleepyfox_ Tilt_Shift voidwalker7 mr_biscuit Dr_Static clutch_or_kick breadcrumb_ zenmode
bonk.png yeetmaster_x sourpatch_ cosmicgoat Pogo_Stick anchovy_ Lil_Thunder fumble_ kn1ghtowl SunnyD4y
gravy_train petrichor_ N0_Scope Mothlight TurboTurnip salty_sam wobblyjelly hexed_ marmalade_ ricochet_
duskrunner glitchwitch emberfall_ jam_sandwich rngesus_ tumbleweed_ Cheddar_ chipmunk_ quasar_k lag_spike_
cozy_goblin Inkwell solarflare_ pixelated_ fiddlesticks lobster_roll overcooked tinfoil_hat midnight_oil
SaltyPretzel capy_bara fumblecore nightowl_ft Gingersnap_ mushroom_man snowbound_ zigzag_ Hazmat_Hal
uncle_static BoneApple8 Brickhouse cloudsurfer plum_crazy nova_nick ByteMe_ shortcircuit wheezy_ krispy_k
Tangent_ sidequest_ noodle_ninja phantom_pho rift_runner dizzy_dot TankTop_Tim crumbs_ ClapBack unlucky7
jollyroger_ quickscope_q OffBrand_ lemon_zest_ frogger_ headphones_on glowstick_ Mr_Meep dashdot_ AFK_Alex
grapejuice_ wrenchmonkey afterimage_ pocketsand stray_sock bubblegum_b couch_co_op parry_pete Roulette_
nitrogen_ speedbump_ hoodie_up tapioca_tom vinyl_vic sundial_ lofi_lena kilowatt_ blank_page rooftop_ruth
jetlag_ MidgameMike static_shock Sprocket_ iron_loaf saltlick_ tuesdays_ opal_ox gnarly_gnome popcorn_pete
ZigZagZoe cable_guy_ bunker_buddy wetpaint_ thumbtack driftwood_d cheerio_ mystery_meat tiptoe_ glowworm_
pepper_jack ClutchCarl fizzbuzz_ lamplight_ otter_pop backseat_bee Hexagon_Hank pinecone_pro latte_lord
Bobbin_ coil_whine toastbot_ ruckus_ drizzle_d OverEasy nimbus_nina quarterpipe slowpoke_sal gumbo_ Cobweb_
paperplane_ mintcondition tinsel_ halfpipe_h moondust_""".split()
def arr(a):
    out=[];line="\t"
    for x in a:
        t='"%s", '%x
        if len(line)+len(t)>110: out.append(line.rstrip()); line="\t"
        line+=t
    out.append(line.rstrip().rstrip(","))
    return "[\n"+"\n".join(out)+"\n]"
src = "class_name Names\n## Name pools: kin names (hand-picked + generated, filtered for anything rude) and bot gamer tags (hand-written).\n## Regenerate with tools/gen_names.py.\n\nconst KIN := " + arr(kin) + "\n\nconst BOT := " + arr(bot) + "\n"
open(__import__("os").path.join(__import__("os").path.dirname(__file__), "..", "scripts", "core", "names.gd"),"w").write(src)
print(len(kin),len(bot))
