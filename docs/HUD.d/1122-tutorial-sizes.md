## Tutorials at every size (--tutorial-walk-shots)

`--tutorial-walk-shots --shots-dir=<dir> [--size=WxH]` (GPU) plays the match tutorial and then the garden tutorial and
saves a frame of every step as `<dir>/<WxH>_<match|garden>_NN_<step>.png`. It fails when the strip or check mark, a
gap step's sign, or the garden's strip, tracker, skip row or spotlight card leaves the safe frame, or a sign sits on a
HUD block or the strip. Run at 1280x720, 3440x1440 and 1024x600.

- The gap steps' world sign ("DASH HERE", "JUMP HERE") is nudged on screen by `LabelFit` (the drawn text only, never
  its place in the world) from `TutorialHud`: inside the safe frame, off the HUD blocks, the strip and the hunter.
- The garden spotlight's hint card stays inside the safe frame like the strip (it used to hug the screen edge).
