## Every menu button makes a sound (`--ui-silent-check`)

`tools/ui_silent_check.gd` opens the title, the Esc menu and its pages, every Settings tab, the results screen, the
pre-match hunter pick, the farm and garden panels and each Black Market tab, points at and presses every Button (a
tab is a Button) and fails on any whose hover or press reaches no cue through `Sfx.play`. Toggles and dropdowns are
flipped (they sound from `UiSfx`). A button that is meant to be silent says so with `UI.sounding(b, "")`.
`UI.button` makes the press sound even when it is given no callback, so a caller that connects `pressed` itself
(the key-binding cells, `ExpFold`, the results "More") is covered without its own player. The match pause menu is not
walked (it needs a running match).
