# Project Boki code style

How code in this repo should read. It applies to people and to coding agents alike. The aim is code a new contributor can open and follow in one pass, and a game that stays lean.

This guide starts from Godot's official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) and adds our own rules. Where the two disagree, this file wins. Architecture rules (where code goes, god-file budgets, checks, Net and saves) are in [AGENTS.md](../AGENTS.md).

## 1. Write for the next human reader

**One statement per line.** No `;` to pack several statements onto one line.
```gdscript
# no
P.hp = 100.0; P.vel = Vector3.ZERO; _spend(P)
# yes
P.hp = 100.0
P.vel = Vector3.ZERO
_spend(P)
```

**Lines at most 120 characters.** Break long calls one argument per line. Long conditions go into a well-named local or function.

**One ternary at most per expression.** If you need two, write an `if` or a small function with a name.
```gdscript
# no
var sink := (DIVE_FALL if diving else DROP_FALL) if dropping else (3.0 if fuel <= 0.0 else glide_fall(v))
# yes
var sink := _sink_rate(v)
```

**Names say what a thing is.** Write `cooldown_left`, not `cdl`. Write `dash_charges`, not `dc`. Short names are fine only for loop indexes (`i`, `j`), well-known math (`x`, `y`, `dt`) and the established short forms in the glossary below. Booleans read as yes/no questions: `is_ready`, `has_key`, `can_dash`.

**Comments say why, not what, and never tell history.**
- A good comment explains a non-obvious reason, a unit, or a source: `# m/s; the canopy brakes a terminal fall in ~0.13s`.
- Don't write history in code: no `(was 14)`, `(owner: ...)`, `(sync62)`, `(movefeel)`. That belongs in the commit message, `docs/decisions/` or the roadmap. The code shows what is true now.
- Every public function gets a `##` doc comment of one or two sentences.

**Small functions.** One job per function. Aim under 40 lines, with 60 as the limit. Pull steps out and name them rather than adding nested blocks.

**Order inside a file**, as in Godot's guide: `class_name`/`extends`, the doc comment, signals, enums, constants, exported vars, public vars, private vars (`_name`), `_ready`/`_process` and other built-ins, public functions, then private functions.

## 2. Don't shadow Godot

Never name a variable, parameter or member after something Godot already defines. A Node already has `name`, `owner`, `position`, `rotation`, `scale`, `size`, `visible`, `transform`, `material` and `modulate`. The global functions include `min`, `max`, `range`, `str`, `load`, `floor`, `round` and `clamp`. Hiding one works until someone uses the built-in meaning, and then it breaks in a way that's hard to see.
```gdscript
# no
func spawn(name: String, position: Vector3) -> void:
# yes
func spawn(boki_name: String, at: Vector3) -> void:
```
Godot's own warnings (`SHADOWED_VARIABLE`, `SHADOWED_VARIABLE_BASE_CLASS`, `SHADOWED_GLOBAL_IDENTIFIER`) catch most of these. Don't silence them.

## 3. Types and data

- **Static types everywhere you can:** `var speed := 5.0`, `func heal(amount: float) -> void`. Typed code is faster and catches mistakes early.
- **Tuning numbers live in `content/`** (JSON) or a named `const` with a unit and a reason, never as a bare number in logic.
- **Dictionaries are for data that comes from JSON.** For state inside the code, use typed vars or a small class.

## 4. Keep the game lean

Every line we add is a line someone has to read, test and keep working. Before you add something:
- **Build only what was asked.** No "while I'm here" features, no options nobody requested, no hooks for imagined future needs.
- **Reuse first.** Search for the system that already does something similar (`grep -rn`) and extend it. Never build a second one next to it.
- **Delete what you replace,** in the same change: old code paths, flags, settings, content entries, checks and docs that no longer apply.
- **No speculative abstraction.** Write the plain version. Add a base class or a generic system only when there's a second real use.
- **No dead or debug leftovers:** no commented-out code, unused parameters, unused variables, stray `print`s or one-off test toggles.
- **Smallest diff that does the job well.** If a change grows past its purpose, stop and split it.
- **Mind performance in hot paths.** Code that runs every frame (`_process`, `tick`, `step`, draw) must not allocate needlessly, scan every entity when it doesn't have to, or load resources.
- **Assets earn their place.** Don't add textures, sounds or scenes that nothing uses. Prefer procedural or shared assets where they look as good.

## 5. Signals, calls and coupling

- Call a typed reference when one object owns another. Use a signal (on `CombatBus` or the node) when the sender shouldn't need to know who listens.
- Don't use `has_method`, `call("name")` or `get_script_method_list` for code we control.
- Systems talk through small public functions with `##` docs. Don't reach into another file's `_private` state.

## 6. How it's enforced

- `python3 tools/style_lint.py` counts long lines, packed `;` statements, nested ternaries, shadowed names and history comments in every file. The old code has many of these, so it works as a **ratchet**: a file may never get worse than `tools/style_baseline.json`, and a new file starts at zero.
- `python3 tools/health.py --strict` runs it, and a ship fails if a file got worse.
- **When you touch a file, leave it better.** Fix the problems in the functions you edit (`style_lint.py --file <path>` lists them), then run `style_lint.py --update` so the lower count is locked in. Never run `--update` to let new problems in.
- The reviewer agent checks every merge against this file and AGENTS.md.

## Glossary of accepted short names

| Name | Means |
|---|---|
| `h` | a Hunter (in kit and Boki code) |
| `k` | a Kin (Boki) |
| `m` | the Match |
| `dt` | delta time in seconds |
| `cd` | cooldown |
| `hp` | health |
| `pos`, `vel`, `dir` | position, velocity, direction |
| `fx`, `sfx` | visual and sound effects |

Anything else should be spelled out.
