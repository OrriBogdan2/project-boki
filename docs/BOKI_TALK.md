# Boki talk

What a Boki says out loud, at home and in a match. All of it is data in `content/rules/boki_lines.json`; `BokiLines` (`scripts/core/boki_lines.gd`) picks the line.

## The rules

- **Short.** At most `max_words` (6) words in a bubble, one sentence. Aim for 2-4. Punctuation and symbols (♥, ♪, ...) don't count as words.
- **Quick.** A bubble stays up for `bubble_s` (2 s), at home (`Home._say`) and in a match (`Match.kin_bark`).
- **Never the same line twice in a row.** Each Boki remembers its last `no_repeat` (10) lines and never says one of them again. If it has said every line it has for that moment, it says the one it said longest ago.
- **Not all the time.** After a line, a Boki waits `cooldown_s` (6 s) before it speaks up again. A trigger marked `direct` (it's answering something you did, or a warning you need) skips the wait.
- **The speech stages stay** (`Care.speech`). Below `grown_stage` (2), a Boki only says its name in a tone, plus a little action: "Cin-cin~ (purrs softly)". At stage 1 it sometimes adds the trigger's one word: "More! Cin-cin~ (purrs softly)". From stage 2 it says real lines.
- **Flavour.** A trigger can have extra lines for an element (the species' type: venom, spore, titan, swarm, gravity, prism, lunar, echo, tempest). A Boki of that element can say them as well as the general ones.

## The file

- `tuning`: the numbers above, plus `act_words` (an action is at most 4 words; a tone and an action that run over the cap together are never paired) and `min_lines` (the fewest general lines a trigger may have).
- `tones`: how a young Boki says its name, by feeling. `{A}` is the first syllable, `{a}` the same in lower case, `{b}` the second syllable, `{F}` / `{f}` / `{U}` the full name as written, lower and upper case (`KinSpeak.fill`).
- `sounds`: noises a tone may use besides the name (grrr, zzz...).
- `alias`: old trigger names that share another trigger's lines (`yelp` and `low_hp` say `hurt` lines).
- `triggers`: one per moment. Each has `feel` (a tone), `word` (the stage-1 word), `acts` (what it does), `lines._` (general lines) and `lines.<element>` (flavour), and `direct` if it skips the cooldown.

To add lines, add them to the trigger's list. `--boki-lines-check` fails a line over the cap, a second sentence, an action that's too long, or a trigger with too few lines.

## The triggers

| Where | Trigger | Fired by |
|---|---|---|
| Farm | `greet`, `greet_cold` | walking up to it or opening a talk (`Home._greeting`) |
| Farm | `petted`, `fed`, `fed_fav`, `fed_no`, `full`, `brushed`, `bath_fav`, `bath_grump`, `nap`, `trained`, `train_miss` | the care actions in `home.gd` |
| Farm | `want_food`, `want_energy`, `want_clean`, `want_joy` | a low need (greeting, `FarmChatter`, too tired to train, starving, overworked) |
| Farm | `crop_ready`, `crop_watered`, `building`, `working`, `rain`, `night`, `chat` (+ the friend's `chat_reply`), `new_boki` | `FarmChatter` (`scripts/home/farm_chatter.gd`) |
| Farm | `hatched` | a Boki hatching |
| Farm | `back_<kind>` (carried_out, boss_kill, revived, stood_over, comforted, knock_together, escaped) | the first time you walk up after an expedition, by how it went (`rec.recall`) |
| Match | `kill`, `owner_down`, `caught`, `extract`, `comfort` (the results screen), `storm` (the islands start falling), `loot` (you open a chest) | `BokiChatter.say` from `match.gd` and `chest_loot.gd` |
| Match | `ability` (its own ability), `level_up` | `BokiChatter.say` from `hunter.gd` |
| Match | `throw`, `refuse`, `hesitate`, `ignore`, `scared`, `revive`, `revive_low`, `wild`, `behind`, `hunter`, `sniper`, `pack`, `boss`, `exit`, `tonic`, `cover`, `goad`, `hurt`, `revived`, `boss_kill` | `Kin.bark` and `KinCompanion` callouts, through `BokiChatter.line` (no cooldown of their own: the 6 s one in `BokiLines`, except the direct triggers) |

`FarmChatter` looks around every 2.5 s: one idle Boki near you may speak about what's going on beside it (a crop, its job, the weather, the time, a need, a friend close by). `Home._say` still keeps it to one voice at a time.

## Not in the JSON

`KinSpeak.reply` (answers to what you type) and `BokiChatter.TUT_HINT` (the tutorial's step hints, a hatchling says its name and the action) keep their own text.
