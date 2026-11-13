"""The soundtracks you can pick in Settings > Audio > Music (content/music/soundtracks.json), one track
per place: the main menu, the garden, an expedition's calm / fight / last moments, a boss, the results
of a run that got out, and training. Written as note data and rendered through the same General MIDI
bank as tools/compose.py; every tune here is our own.

  Classic Adventure  warm MIDI orchestra in the old MMO way: flute, lute, harp, strings, light drums
  Lantern Lo-fi      the same places as slow lo-fi beats: electric piano, soft swung kit, tape dust

Each loop is a whole number of bars with the ringing tail wrapped onto its start (compose.render), then
set to one loudness with ffmpeg loudnorm (a single linear gain, so the loop seam is untouched).

    python3 tools/compose_soundtracks.py                 # every track into audio/
    python3 tools/compose_soundtracks.py classic_menu    # one track
    python3 tools/compose_soundtracks.py --previews DIR  # also 20 s MP3 previews into DIR
"""
import json, os, subprocess, sys, tempfile, wave
import numpy as np
from scipy.signal import butter, lfilter, resample
from compose import Song, D, OUT, SR, ensure_bank, render, pad, arp, bass, drums, melody, phrase_gen

TARGET_LUFS = -14.0     # integrated loudness of every track (the original score sits at -13 to -15)
TARGET_TP = -1.0        # dBTP ceiling: the gain stops short of this rather than limiting
VORBIS_BLOCK = 64       # samples: the encoder pads a file's end to a multiple of this (a gap at the loop)
PREVIEW_S = 20.0        # seconds of each track in a listen-sheet preview
EPIANO, FINGER_BASS, VIBES, MUTED_TPT = 4, 33, 11, 59     # General MIDI programs compose.P doesn't name


def tune(s, ch, notes, bar, vel=96, octave=0, legato=1.0):
    """melody(), but a line that doesn't fill whole bars is a typo in the note data."""
    beats = sum(d for _, d in notes)
    assert abs(beats / s.beats - round(beats / s.beats)) < 1e-6, (s.name, bar, beats)
    melody(s, ch, notes, bar, vel, octave, legato)

def strum(s, ch, prog, hits, vel=60, octave=-1):
    """A lute strum: each chord's notes a hair apart, low to high, on the given beats of every bar."""
    for bar, d in enumerate(prog):
        for t, dur in hits:
            for i, k in enumerate(s.chord(d, octave)):
                s.note(ch, bar * s.beats + t + i * 0.03, k, dur, vel - i * 4)

def major_v(s, ch, bar, dur, vel, octave=-1):
    """The dominant chord with its third raised (harmonic minor): pulls home harder than the scale's own."""
    r = s.deg(4, octave)
    for k in (r, r + 4, r + 7):
        s.note(ch, bar * s.beats, k, dur, vel)


# ------------------------------------------------------------------ Classic Adventure
def classic_menu():
    # "Hearthlight": the main theme. D major, flute over harp and lute; the horn answers, then everyone.
    s = Song('classic_menu', 84, 32, root=62, mode='major', seed=101)
    s.inst(0, 'flute', 100); s.inst(1, 'harp', 84); s.inst(2, 'nylon', 74); s.inst(3, 'ac_bass', 84)
    s.inst(4, 'strings', 60); s.inst(5, 'horn', 90); s.inst(6, 'oboe', 80)
    A = [0, 4, 5, 3, 0, 3, 4, 4]; A2 = [0, 4, 5, 3, 0, 3, 4, 0]; B = [5, 3, 0, 4, 5, 3, 1, 4]
    prog = A + A2 + B + A
    arp(s, 1, prog, [0, 1, 2, 3, 2, 1, 0, 2], step=0.5, vel=62, octave=-1, ring=2.0)
    strum(s, 2, prog, [(0, 1.8), (2, 1.8)], vel=58)
    bass(s, 3, prog, [(0, 2.0), (2, 2.0)], vel=78)
    pad(s, 4, prog[8:], vel=50)
    theme = [(4, 1.5), (2, 0.5), (4, 1), (7, 1), (6, 2), (4, 1), (5, 1), (5, 1.5), (4, 0.5), (2, 1), (0, 1),
             (1, 1), (2, 1), (3, 2), (4, 1.5), (2, 0.5), (4, 1), (7, 1), (8, 2), (7, 1), (5, 1),
             (6, 1), (5, 1), (4, 1), (6, 1)]
    tune(s, 0, theme + [(4, 3), (None, 1)], 0, 98)
    tune(s, 0, theme + [(7, 3), (None, 1)], 8, 100)
    answer = [(5, 3), (4, 1), (3, 2), (5, 2), (4, 3), (2, 1), (1, 4),
              (0, 2), (2, 2), (3, 3), (5, 1), (1, 2), (3, 2), (4, 2), (6, 2)]
    tune(s, 5, answer, 16, 88, octave=-1)
    tune(s, 0, theme + [(4, 3), (None, 1)], 24, 102)
    tune(s, 6, theme + [(4, 3), (None, 1)], 24, 70, octave=-1)
    drums(s, [(1, 'tamb', 0.45), (3, 'tamb', 0.5), (0, 'tom_lo', 0.5)], start=16)
    s.note(9, 0, D['triangle'], 1, 50)
    return s

def classic_base():
    # "Furrow and Hearth": the garden. A G major waltz, recorder and lute, pizzicato and a shaker.
    s = Song('classic_base', 112, 48, beats=3, root=67, mode='major', seed=102)
    s.inst(0, 'recorder', 98); s.inst(1, 'harp', 72); s.inst(2, 'nylon', 76); s.inst(3, 'ac_bass', 82)
    s.inst(4, 'pizz', 66); s.inst(5, 'flute', 90); s.inst(6, 'slow_strings', 48)
    A = [0, 0, 3, 0, 0, 0, 4, 4, 0, 0, 3, 3, 0, 4, 0, 0]
    B = [5, 5, 3, 3, 0, 0, 4, 4, 5, 5, 3, 3, 1, 4, 0, 4]
    prog = A + B + A
    bass(s, 3, prog, [(0, 1.0)], vel=80, fifths=False)
    for bar, d in enumerate(prog):
        for k in s.chord(d, -1):
            s.note(2, bar * 3 + 1, k, 0.6, 54); s.note(2, bar * 3 + 2, k, 0.6, 48)
    arp(s, 1, prog[16:32], [0, 1, 2, 3, 2, 1], step=0.5, vel=60, octave=0)
    pad(s, 6, prog[16:], vel=44)
    a = [(0, 1), (2, 1), (4, 1), (7, 2), (6, 1), (5, 1), (3, 1), (5, 1), (4, 3),
         (4, 1), (5, 1), (4, 1), (2, 1), (4, 1), (2, 1), (6, 1), (5, 1), (4, 1), (1, 3),
         (0, 1), (2, 1), (4, 1), (7, 2), (9, 1), (8, 1), (7, 1), (5, 1), (3, 1), (5, 1), (7, 1),
         (4, 2), (2, 1), (1, 1), (6, 1), (4, 1), (0, 3), (None, 1), (-3, 1), (-1, 1)]
    tune(s, 0, a, 0, 96)
    b = phrase_gen(s, B, [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [3]], start_deg=4, leap=0.2)
    tune(s, 5, b, 16, 90)
    tune(s, 0, a, 32, 98)
    tune(s, 4, a, 32, 58, octave=-1)
    drums(s, [(0, 'shaker', 0.5), (1, 'shaker', 0.3), (2, 'shaker', 0.35)], start=16)
    drums(s, [(0, 'bongo_lo', 0.5), (2, 'bongo_hi', 0.35)], start=32)
    return s

def classic_calm():
    # "Wayfarer's Road": exploring an expedition. A dorian, oboe and flute over harp, a hand drum.
    s = Song('classic_calm', 92, 32, root=69, mode='dorian', seed=103)
    s.inst(0, 'oboe', 90); s.inst(1, 'harp', 80); s.inst(2, 'nylon', 62); s.inst(3, 'cello', 74)
    s.inst(4, 'slow_strings', 52); s.inst(5, 'flute', 92)
    A = [0, 6, 3, 0, 0, 6, 4, 4]; B = [2, 6, 3, 0, 2, 6, 4, 4]
    prog = A + B + A + B
    arp(s, 1, prog, [0, 2, 1, 3, 2, 1, 0, 1], step=0.5, vel=58, octave=-1, ring=2.2)
    bass(s, 3, prog, [(0, 3.5)], vel=70, fifths=False)
    pad(s, 4, prog, vel=42)
    strum(s, 2, prog[16:], [(1, 0.8), (2.5, 0.8)], vel=46)
    line = [(4, 2), (2, 1), (3, 1), (1, 1.5), (3, 0.5), (1, 2), (0, 1), (3, 1), (5, 2), (4, 4),
            (7, 1), (6, 1), (4, 2), (6, 1.5), (5, 0.5), (3, 2), (4, 2), (6, 1), (8, 1), (4, 3), (None, 1)]
    tune(s, 0, line, 0, 88)
    tune(s, 5, phrase_gen(s, B, [[2, 1, 1], [3, 1], [1, 1, 2], [4]], start_deg=4, leap=0.2), 8, 84)
    tune(s, 5, line, 16, 92)
    tune(s, 0, phrase_gen(s, B, [[1.5, 0.5, 2], [2, 2], [1, 1, 1, 1], [4]], start_deg=2, leap=0.2), 24, 84)
    drums(s, [(0, 'bongo_lo', 0.5), (1.5, 'bongo_hi', 0.3), (2, 'bongo_lo', 0.35), (3, 'shaker', 0.3)], start=8)
    return s

def classic_tense():
    # "Steel at Dusk": a fight. D minor, fiddle over a pizzicato drive, low strings and toms.
    s = Song('classic_tense', 120, 32, root=62, mode='minor', seed=104)
    s.inst(0, 'fiddle', 96); s.inst(1, 'pizz', 76); s.inst(2, 'tremolo', 56); s.inst(3, 'cello', 92)
    s.inst(4, 'horn', 78); s.inst(5, 'timpani', 96)
    A = [0, 0, 5, 6, 0, 0, 3, 4]; B = [3, 3, 0, 0, 5, 6, 4, 4]
    prog = A + A + B + B
    pad(s, 2, prog, vel=50)
    for bar, d in enumerate(prog):
        for i in range(8):
            s.note(1, bar * 4 + i * 0.5, s.chord(d, -1)[(0, 1, 2, 1)[i % 4]], 0.3, 66 - (8 if i % 2 else 0))
            s.note(3, bar * 4 + i * 0.5, s.deg(d, -2) + (12 if i == 6 else 0), 0.4, 88 - (12 if i % 2 else 0))
        if bar % 2 == 0: s.note(5, bar * 4, s.deg(0, -2), 1.0, 96)
    a = [(0, 0.5), (2, 0.5), (4, 1), (4, 0.5), (5, 0.5), (4, 1), (2, 1), (1, 0.5), (0, 0.5), (1, 2),
         (2, 0.5), (4, 0.5), (5, 1), (4, 0.5), (2, 0.5), (0, 1), (1, 1), (3, 1), (6, 2),
         (0, 0.5), (2, 0.5), (4, 1), (4, 0.5), (5, 0.5), (4, 1), (7, 1), (6, 0.5), (4, 0.5), (5, 2),
         (3, 1), (5, 1), (7, 1), (5, 1), (4, 3), (None, 1)]
    tune(s, 0, a, 0, 94)
    tune(s, 0, a, 8, 100); tune(s, 4, a, 8, 70, octave=-1)
    b = phrase_gen(s, B * 2, [[1, 0.5, 0.5, 2], [0.5, 0.5, 1, 2], [1.5, 0.5, 1, 1], [3, -1]], start_deg=4, leap=0.3)
    tune(s, 0, b, 16, 96)
    tune(s, 4, [(0, 8), (2, 8), (-2, 8), (-1, 8)], 16, 66, octave=-1)
    drums(s, [(0, 'tom_lo', 0.8), (1, 'side', 0.5), (2, 'tom_lo', 0.6), (2.5, 'tom_lo', 0.5), (3, 'side', 0.6),
              (0.5, 'hat', 0.3), (1.5, 'hat', 0.3), (2.5, 'hat', 0.3), (3.5, 'hat', 0.35)], start=8)
    return s

def classic_final():
    # "The Narrowing Sky": the last moments. E minor and quick, tremolo strings climbing, brass and drums.
    s = Song('classic_final', 144, 32, root=64, mode='minor', seed=105)
    s.inst(0, 'trumpet', 92); s.inst(1, 'tremolo', 76); s.inst(2, 'strings', 66); s.inst(3, 'cello', 96)
    s.inst(4, 'brass', 90); s.inst(5, 'timpani', 104); s.inst(6, 'horn', 82)
    A = [0, 0, 5, 5, 3, 3, 4, 4]
    prog = A * 4
    for bar, d in enumerate(prog):
        for i in range(16):
            s.note(1, bar * 4 + i * 0.25, s.chord(d, 0)[(0, 1, 2, 1)[i % 4]], 0.22, 60 + (10 if i % 4 == 0 else 0))
        for i in range(8):
            s.note(3, bar * 4 + i * 0.5, s.deg(d, -2), 0.4, 92 - (12 if i % 2 else 0))
        if d == 4: major_v(s, 4, bar, 0.6, 96)
        else:
            for k in s.chord(d, -1): s.note(4, bar * 4, k, 0.6, 92)
        s.note(5, bar * 4, s.deg(0, -2), 1, 104); s.note(5, bar * 4 + 2.5, s.deg(0, -2), 1, 86)
        if bar % 8 == 7:
            for i in range(8): s.note(5, bar * 4 + i * 0.5, s.deg(0, -2), 0.5, 70 + i * 6)
    call = [(0, 1), (0, 0.5), (0, 0.5), (4, 2), (3, 1), (2, 1), (1, 2), (2, 1), (2, 0.5), (2, 0.5), (5, 2),
            (4, 1), (3, 1), (1, 2), (0, 1), (2, 1), (4, 1), (7, 1), (6, 3), (None, 1),
            (7, 1), (7, 0.5), (7, 0.5), (9, 2), (8, 1), (7, 1), (5, 2), (4, 1), (5, 1), (6, 2)]
    tune(s, 0, call + [(4, 4)], 8, 98)
    tune(s, 6, call + [(4, 4)], 24, 86, octave=-1)
    tune(s, 2, [(0, 8), (2, 8), (5, 8), (4, 8)] * 2, 0, 58)
    drums(s, [(0, 'kick', 0.9), (1, 'snare', 0.6), (2, 'kick', 0.8), (3, 'snare', 0.7),
              (3.5, 'snare', 0.4), (0.5, 'hat', 0.35), (1.5, 'hat', 0.35), (2.5, 'hat', 0.35)], start=8)
    for bar in (7, 15, 23, 31): s.note(9, bar * 4 + 3, D['crash'], 1.0, 70)
    return s

def classic_boss():
    # "Under the Old Crown": a boss. C phrygian, a cello ostinato under brass, choir and timpani.
    s = Song('classic_boss', 104, 24, root=60, mode='phrygian', seed=106)
    s.inst(0, 'horn', 98); s.inst(1, 'brass', 96); s.inst(2, 'choir', 70); s.inst(3, 'cello', 100)
    s.inst(4, 'timpani', 112); s.inst(5, 'trombone', 92); s.inst(6, 'taiko', 104)
    prog = [0, 0, 1, 0, 0, 0, 6, 5] * 3
    for bar, d in enumerate(prog):
        for i, step in enumerate((0, 0, 1, 0, 0, 0, 3, 1)):
            s.note(3, bar * 4 + i * 0.5, s.deg(d + step, -2), 0.45, 100 - (14 if i % 2 else 0))
        if bar % 2 == 0:
            for k in s.chord(d, -1): s.note(2, bar * 4, k, 7.8, 64)
        for t in (0, 1.5, 3.5):
            for k in s.chord(d, -1): s.note(1, bar * 4 + t, k, 0.4, 100 if t == 0 else 84)
        s.note(4, bar * 4, s.deg(0, -2), 1, 112)
        s.note(6, bar * 4 + 2, 48, 1, 96); s.note(6, bar * 4 + 2.5, 48, 1, 80)
        if bar % 4 == 3:
            for i in range(8): s.note(4, bar * 4 + i * 0.5, s.deg(0, -2), 0.5, 76 + i * 5)
    theme = [(4, 3), (3, 1), (1, 4), (0, 2), (1, 2), (3, 4), (4, 3), (5, 1), (4, 2), (3, 2), (1, 8)]
    tune(s, 0, theme, 8, 98)
    tune(s, 5, theme, 16, 92, octave=-1); tune(s, 0, theme, 16, 102, octave=1)
    for bar in (0, 8, 16): s.note(9, bar * 4, D['crash'], 2, 92)
    return s

def classic_victory():
    # "Homeward Bells": the results of a run that got out. C major, a trumpet call, then flute and bells.
    s = Song('classic_victory', 100, 16, root=60, mode='major', seed=107)
    s.inst(0, 'trumpet', 96); s.inst(1, 'harp', 80); s.inst(2, 'strings', 62); s.inst(3, 'ac_bass', 80)
    s.inst(4, 'flute', 96); s.inst(5, 'glock', 64); s.inst(6, 'horn', 82)
    prog = [0, 3, 4, 0, 5, 3, 1, 4, 0, 3, 4, 5, 3, 4, 0, 4]
    pad(s, 2, prog, vel=52)
    arp(s, 1, prog, [0, 1, 2, 3, 2, 1, 0, 1], step=0.5, vel=60, octave=0)
    bass(s, 3, prog, [(0, 1.5), (2, 1.5)], vel=78)
    call = [(0, 0.5), (2, 0.5), (4, 1), (7, 2), (5, 1), (3, 0.5), (5, 0.5), (8, 2), (6, 1), (4, 1), (6, 1), (8, 1),
            (7, 3), (None, 1)]
    tune(s, 0, call, 0, 100); tune(s, 6, call, 0, 72, octave=-1)
    song = [(9, 1), (7, 1), (5, 1), (7, 1), (8, 2), (5, 2), (6, 1), (5, 1), (3, 1), (1, 1), (4, 4),
            (2, 1), (4, 1), (7, 1), (9, 1), (8, 1.5), (7, 0.5), (5, 2), (5, 1), (7, 1), (8, 1), (6, 1),
            (7, 2), (6, 1), (4, 1)]
    tune(s, 4, song, 4, 96, octave=-1)
    tune(s, 5, song, 4, 58)
    tune(s, 0, call[:-2] + [(4, 2), (6, 2)], 12, 96)
    drums(s, [(0, 'kick', 0.5), (1, 'tamb', 0.4), (2, 'kick', 0.4), (3, 'tamb', 0.45)])
    s.note(9, 0, D['crash'], 2, 70)
    return s

def classic_training():
    # "Practice Yard": training. A mixolydian and bouncy, banjo and marimba, claps and a woodblock.
    s = Song('classic_training', 112, 24, root=69, mode='mixolydian', seed=108)
    s.inst(0, 'whistle', 88); s.inst(1, 'banjo', 76); s.inst(2, 'marimba', 74); s.inst(3, 'ac_bass', 86)
    s.inst(4, 'pizz', 64); s.inst(5, 'accordion', 52)
    prog = [0, 0, 6, 0, 0, 0, 4, 4, 3, 3, 0, 0, 6, 6, 4, 4, 0, 0, 6, 0, 3, 4, 0, 0]
    bass(s, 3, prog, [(0, 0.8), (1, 0.8), (2, 0.8), (3, 0.8)], vel=82)
    for bar, d in enumerate(prog):
        for i in range(8):
            s.note(1, bar * 4 + i * 0.5, s.chord(d, 0)[(0, 2, 1, 2)[i % 4]], 0.35, 62 - (8 if i % 2 else 0))
    arp(s, 2, prog[8:], [0, 1, 2, 3, 2, 1, 2, 3], step=0.5, vel=58, octave=0)
    pad(s, 5, prog, vel=40)
    a = [(4, 0.5), (4, 0.5), (5, 1), (4, 1), (2, 1), (6, 1), (5, 0.5), (4, 0.5), (3, 2), (4, 0.5), (4, 0.5),
         (5, 1), (7, 1), (8, 1), (6, 3), (None, 1)]
    b = [(7, 1), (6, 0.5), (5, 0.5), (4, 2), (5, 1), (4, 0.5), (3, 0.5), (2, 2), (6, 1), (5, 1), (4, 1), (2, 1),
         (4, 3), (None, 1)]
    tune(s, 0, a + b, 0, 92)
    tune(s, 4, a + b, 16, 60, octave=0)
    tune(s, 0, a, 16, 96)
    drums(s, [(1, 'clap', 0.5), (3, 'clap', 0.55), (0, 'kick', 0.6), (2, 'kick', 0.5),
              (0.5, 'wood_hi', 0.35), (2.5, 'wood_lo', 0.35)])
    return s


# ------------------------------------------------------------------ Lantern Lo-fi
# One recipe, eight moods: seventh chords on a swung electric piano, a round bass, a soft kit, a sparse
# lead. What changes per place is the key, tempo, progression, lead and how busy the drums are.
LOFI = {   # id: (bpm, root, mode, progression of 4 bars, lead program, seed, drums 0..2)
    'menu': (78, 65, 'major', [0, 5, 3, 4], VIBES, 201, 1),
    'base': (72, 67, 'major', [3, 2, 1, 4], 'kalimba', 202, 1),
    'calm': (80, 62, 'dorian', [0, 3, 0, 6], 'flute', 203, 1),
    'tense': (90, 64, 'minor', [0, 5, 6, 4], MUTED_TPT, 204, 2),
    'final': (96, 69, 'minor', [0, 6, 5, 4], 'tremolo', 205, 2),
    'boss': (84, 60, 'phrygian', [0, 1, 0, 6], 'oohs', 206, 2),
    'victory': (84, 70, 'major', [3, 4, 2, 5], 'celesta', 207, 1),
    'training': (88, 69, 'mixolydian', [0, 6, 3, 0], 'marimba', 208, 1),
}
SWING = 0.16    # beats an off-beat eighth is pushed late

def lofi(ctx):
    bpm, root, mode, prog4, lead, seed, busy = LOFI[ctx]
    s = Song('lofi_' + ctx, bpm, 24, root=root, mode=mode, seed=seed)
    s.inst(0, lead, 84); s.inst(1, EPIANO, 82); s.inst(2, FINGER_BASS, 90)
    prog = prog4 * 6
    for bar, d in enumerate(prog):
        b0 = bar * 4
        seventh = s.chord(d, -1) + [s.deg(d + 6, -1)]
        for t, dur, v in ((0, 1.4, 66), (1.5 + SWING, 0.4, 52), (2.5 + SWING, 1.3, 58)):
            for i, k in enumerate(seventh):
                s.note(1, b0 + t + i * 0.02, k, dur, v - i * 3)
        s.note(2, b0, s.deg(d, -2), 1.4, 88)
        s.note(2, b0 + 2.5 + SWING, s.deg(d + (4 if bar % 2 else 0), -2), 1.2, 76)
        hats = [(i * 0.5 + (SWING if i % 2 else 0), 'hat', 0.32 + (0.08 if i % 2 == 0 else 0)) for i in range(8)]
        kit = [(0, 'kick', 0.8), (1, 'side' if busy < 2 else 'snare', 0.55), (2.5 + SWING, 'kick', 0.6), (3, 'side' if busy < 2 else 'snare', 0.6)]
        if bar >= 2 or busy:
            for t, dk, vs in kit + (hats if busy else hats[::2]):
                s.note(9, b0 + t, D[dk], 1.0, 82 * vs)
    rh = [[2, 1, 1], [3, -1], [1, 1, 2], [4]] if busy < 2 else [[1, 0.5, 0.5, 2], [1.5, 0.5, 2], [1, 1, 1, 1], [3, -1]]
    tune(s, 0, phrase_gen(s, prog[:8], rh, start_deg=4, leap=0.2), 4, 80)
    tune(s, 0, phrase_gen(s, prog[:8], rh[::-1], start_deg=2, leap=0.3), 16, 80, octave=1 if busy < 2 else 0)
    return s

def lofi_dust(x, seed):
    """Tape and vinyl: a gentle low-pass, soft saturation and a little crackle under the music (seeded,
    so a render repeats; set against the track's own level)."""
    x = loop_filter(butter(2, 4200 / (SR / 2), 'low'), x)
    x = np.tanh(x / np.max(np.abs(x)) * 1.2)
    rms = np.sqrt(np.mean(x ** 2))
    rng = np.random.default_rng(seed)
    clicks = (rng.random((len(x), 1)) < 4.0 / SR) * rng.normal(0, 0.8 * rms, (len(x), 1))
    hiss = loop_filter(butter(1, 3000 / (SR / 2), 'low'), rng.normal(0, 0.06 * rms, (len(x), 1)))
    return x + clicks + hiss

def loop_filter(ba, x):
    """A filter over a loop as it plays: run through twice, keep the second pass, so the start already
    carries the end's state and the seam stays smooth."""
    return lfilter(ba[0], ba[1], np.concatenate([x, x]), axis=0)[len(x):]

def fit_blocks(x):
    """Stretches a loop by under 64 samples (a few millionths) to a whole number of encoder blocks, so
    the file ends exactly on the loop point. The FFT resample treats the signal as periodic: the seam
    stays continuous."""
    n = len(x) - len(x) % VORBIS_BLOCK
    return x if n == len(x) else resample(x, n, axis=0)

def soften_peaks(x):
    """A soft ceiling just above the music's loudest normal moments: the bank now and then fires a lone
    spike (a stolen voice) that would otherwise set the gain for the whole track."""
    t = np.percentile(np.abs(x), 99.9) * 1.25
    a = np.abs(x)
    knee = 0.7 * t
    over = a > knee
    a[over] = knee + 0.3 * t * np.tanh((a[over] - knee) / (0.3 * t))
    return np.sign(x) * a

TRACKS = {f.__name__: f for f in [classic_menu, classic_base, classic_calm, classic_tense, classic_final,
                                  classic_boss, classic_victory, classic_training]}
TRACKS.update({'lofi_' + c: (lambda c=c: lofi(c)) for c in LOFI})


# ------------------------------------------------------------------ loudness and files
def loudness(path):
    """ffmpeg loudnorm's measurement of a file: (integrated LUFS, true peak dBTP)."""
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', path, '-af', 'loudnorm=print_format=json',
                        '-f', 'null', '-'], capture_output=True, text=True, check=True).stderr
    m = json.loads(r[r.rindex('{'):r.rindex('}') + 1])
    return float(m['input_i']), float(m['input_tp'])

def write_track(name, x, previews):
    tmp = tempfile.NamedTemporaryFile(suffix='.wav', delete=False).name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x / (np.max(np.abs(x)) or 1) * 0.5, -1, 1) * 32767).astype(np.int16).tobytes())
    i, tp = loudness(tmp)
    gain = min(TARGET_LUFS - i, TARGET_TP - tp)
    out = os.path.join(OUT, 'music_%s.ogg' % name)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-af', 'volume=%.2fdB' % gain,
                    '-c:a', 'libvorbis', '-q:a', '2', out], check=True)
    if previews:
        fade = PREVIEW_S - 1.5
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', out, '-t', str(PREVIEW_S), '-af',
                        'afade=t=out:st=%.1f:d=1.5' % fade, '-c:a', 'libmp3lame', '-b:a', '96k',
                        os.path.join(previews, '%s.mp3' % name)], check=True)
    os.unlink(tmp)
    i2, tp2 = loudness(out)
    print('%-17s %5.1fs %4d KB  %6.1f LUFS %5.1f dBTP' % (name, len(x) / SR, os.path.getsize(out) // 1024, i2, tp2))

if __name__ == '__main__':
    args = sys.argv[1:]
    previews = ''
    if '--previews' in args:
        previews = args.pop(args.index('--previews') + 1); args.remove('--previews')
        os.makedirs(previews, exist_ok=True)
    ensure_bank()
    for n in args or list(TRACKS):
        x = render(TRACKS[n]())
        if n.startswith('lofi_'):
            x = lofi_dust(x, LOFI[n[5:]][5])
        write_track(n, soften_peaks(fit_blocks(x)), previews)
