#!/usr/bin/env python3
"""make_audio.py: build the game's starter sound effects and music.

    python3 tools/audio/make_audio.py [--kits ~/fourfold-art/kits/audio] [name ...]

It writes game/assets/sound/ and game/assets/music/. Two kinds of sound are made:

- Picked: recordings copied out of free CC0 sound packs, under the game's own names (PICKS
  below). They need the packs in the --kits folder; game/assets/README.md says how to get them.
  Without the folder this step is skipped.
- Made: everything with a note in it (bells, the chant, the music) is synthesised here, from
  the recipe the first, TypeScript version of the game used (src/ui/audio.ts at the tag
  typescript-game). Python's standard library only.

Name one or more sounds (as "heal" or "calm_0") to make only those.
All of it is a stand-in: to replace a sound, save a file of the same name over it.
"""
import argparse
import math
import os
import random
import shutil
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOUND = os.path.join(ROOT, "game", "assets", "sound")
MUSIC = os.path.join(ROOT, "game", "assets", "music")

# ---------------------------------------------------------------- picked from the packs

# The game's name for a sound -> the pack's folder under --kits, and the file in it.
PICKS = {
    "swing_1": ("artisticdude-rpg", "RPG Sound Pack/battle/swing.wav"),
    "swing_2": ("artisticdude-rpg", "RPG Sound Pack/battle/swing2.wav"),
    "swing_3": ("artisticdude-rpg", "RPG Sound Pack/battle/swing3.wav"),
    "fire_1": ("oga-80-rpg-sfx", "spell_fire_07.ogg"),
    "fire_2": ("oga-80-rpg-sfx", "spell_fire_06.ogg"),
    "fire_3": ("oga-80-rpg-sfx", "spell_fire_01.ogg"),
    "spell_1": ("oga-80-rpg-sfx", "spell_01.ogg"),
    "spell_2": ("oga-80-rpg-sfx", "spell_02.ogg"),
    "strike_1": ("oga-80-rpg-sfx", "blade_01.ogg"),
    "strike_2": ("oga-80-rpg-sfx", "blade_02.ogg"),
    "strike_3": ("kenney-rpg", "OGG/chop.ogg"),
    "blow_1": ("oga-100-sfx", "hit_01.ogg"),
    "blow_2": ("oga-100-sfx", "hit_02.ogg"),
    "blow_3": ("oga-100-sfx", "hit_03.ogg"),
    "guard_1": ("oga-80-rpg-sfx", "metal_03.ogg"),
    "guard_2": ("artisticdude-rpg", "RPG Sound Pack/inventory/armor-light.wav"),
    "death_1": ("oga-80-rpg-sfx", "creature_hurt_01.ogg"),
    "death_2": ("oga-80-rpg-sfx", "creature_die_01.ogg"),
    "boom_1": ("oga-100-sfx", "slam_01.ogg"),
    "boom_2": ("oga-100-sfx", "slam_03.ogg"),
    "stones_1": ("oga-80-rpg-sfx", "stones_01.ogg"),
    "stones_2": ("oga-80-rpg-sfx", "stones_02.ogg"),
    "ui_click": ("kenney-ui", "click1.wav"),
}

# ---------------------------------------------------------------- the synthesiser

SR = 22050          # sound effects
MUSIC_SR = 16000    # music: nothing in it is higher than a small bell
BEAT = 0.8
BAR = BEAT * 4

# D minor. The Infirmary's progression ends on a major dominant, which keeps it uneasy.
PROG = [
    [(38, (50, 53, 57)), (34, (46, 50, 53)), (41, (48, 53, 57)), (36, (48, 52, 55))],
    [(38, (50, 53, 57)), (43, (46, 50, 55)), (34, (46, 50, 53)), (33, (45, 49, 52))],
    [(38, (50, 53, 57)), (34, (46, 50, 53)), (41, (48, 53, 57)), (36, (48, 52, 55))],
]
# (how many times the note, how loud, how long it rings): what makes a sine wave a bell
BELL_PARTIALS = [(0.5, 0.6, 1.4), (1, 1, 1), (1.19, 0.45, 0.8), (1.56, 0.25, 0.6), (2, 0.3, 0.5), (2.51, 0.15, 0.35), (4.1, 0.06, 0.2)]


def mf(note):
    """A MIDI note number as a frequency."""
    return 440.0 * 2 ** ((note - 69) / 12.0)


class Tape:
    """Sound being built: a dry part, and a part sent to the echo of a stone hall. With
    loop=True whatever runs off the end comes back in at the start, so the end joins the start."""

    def __init__(self, seconds, rate, loop=False):
        self.rate = rate
        self.n = int(seconds * rate)
        self.dry = [0.0] * self.n
        self.wet = [0.0] * self.n
        self.loop = loop

    def add(self, at, samples, wet=0.0):
        n, dry, send = self.n, self.dry, self.wet
        i = int(at * self.rate)
        for v in samples:
            if i >= n:
                if not self.loop:
                    break
                i -= n
            dry[i] += v
            if wet:
                send[i] += v * wet
            i += 1

    def mix(self, hall=0.5):
        """The dry part plus the hall's echo of the wet part."""
        echo = reverb(self.wet, self.rate, self.loop)
        return [d + hall * e for d, e in zip(self.dry, echo)]


def reverb(x, rate, loop):
    """A small stone hall: four echoes that feed back, smeared by two all-pass filters."""
    k = rate / 44100.0
    out = [0.0] * len(x)
    passes = 2 if loop else 1  # a loop is run through twice, so its tail is there at the start
    for delay, feedback in ((1557, 0.86), (1617, 0.85), (1491, 0.87), (1422, 0.84)):
        d = max(1, int(delay * k))
        buf = [0.0] * d
        low = 0.0
        j = 0
        for p in range(passes):
            last = p == passes - 1
            for i, v in enumerate(x):
                y = buf[j]
                low = y * 0.7 + low * 0.3  # the hall soaks up the high end
                buf[j] = v + low * feedback
                j += 1
                if j == d:
                    j = 0
                if last:
                    out[i] += y * 0.25
    for delay in (225, 556):
        d = max(1, int(delay * k))
        buf = [0.0] * d
        j = 0
        for i, v in enumerate(out):
            y = buf[j]
            buf[j] = v + y * 0.5
            out[i] = y - v * 0.5
            j += 1
            if j == d:
                j = 0
    return out


def bell(rate, f, vol, long=1.0):
    """A struck bell: seven sine waves, the higher ones dying sooner."""
    longest = int(3.2 * 1.4 * long * rate)
    out = [0.0] * longest
    attack = int(0.004 * rate)
    for ratio, amp, decay in BELL_PARTIALS:
        if f * ratio > rate * 0.45:
            continue
        n = int(3.2 * decay * long * rate)
        step = 2 * math.pi * f * ratio / rate
        fall = math.exp(-7.0 / n)
        a = vol * amp
        sin = math.sin
        for i in range(n):
            out[i] += sin(step * i) * a * (i / attack if i < attack else 1.0)
            a *= fall
    return out


def saws(rate, f, n, cents, vibrato=0.0):
    """Sawtooth waves a few cents apart, added together; with vibrato they waver like voices."""
    out = [0.0] * n
    for k, c in enumerate(cents):
        step = f * 2 ** (c / 1200.0) / rate
        phase = 0.13 * k
        wob = 2 * math.pi * (4.6 + c * 0.03) / rate
        depth = vibrato * 0.00058  # five cents, as a share of the pitch
        for i in range(n):
            phase += step * (1.0 + depth * math.sin(wob * i)) if vibrato else step
            if phase >= 1.0:
                phase -= 1.0
            out[i] += 2.0 * phase - 1.0
    return out


def filtered(x, rate, kind, f1, f2=0.0, q=0.707):
    """A two-pole filter (low, high or band) whose pitch can slide from f1 to f2."""
    out = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    n = len(x)
    b0 = b1 = b2 = a1 = a2 = 0.0
    for i, v in enumerate(x):
        if i % 32 == 0:
            f = f1 * (f2 / f1) ** (i / n) if f2 else f1
            w = 2 * math.pi * min(f, rate * 0.45) / rate
            alpha = math.sin(w) / (2 * q)
            cw = math.cos(w)
            a0 = 1 + alpha
            if kind == "low":
                b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
            elif kind == "high":
                b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
            else:
                b0, b1, b2 = alpha, 0.0, -alpha
            b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, -2 * cw / a0, (1 - alpha) / a0
        y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, y
        out[i] = y
    return out


def shaped(x, points):
    """Scales a sound by a loudness that moves in straight lines between (share of the way, level)."""
    n = len(x)
    out = [0.0] * n
    k = 0
    for i, v in enumerate(x):
        t = i / n
        while k + 2 < len(points) and t >= points[k + 1][0]:
            k += 1
        (t0, a0), (t1, a1) = points[k], points[k + 1]
        out[i] = v * (a0 + (a1 - a0) * min(max((t - t0) / (t1 - t0), 0.0), 1.0))
    return out


def pad(rate, f, dur, vol, cut):
    """The drone under everything: two sawtooths through a low filter, swelling and fading."""
    n = int(dur * rate)
    return shaped(filtered(saws(rate, f, n, (-8, 7)), rate, "low", cut), [(0, 0), (0.35, vol), (1, 0)])


def choir(rate, f, dur, vol):
    """One voice of the drowned choir: sawtooths sung through a vowel-shaped filter."""
    n = int(dur * rate)
    sung = filtered(saws(rate, f, n, (-9, 0, 8), vibrato=1.0), rate, "band", 760, q=1.6)
    return shaped(sung, [(0, 0), (0.3, vol), (0.75, vol), (1, 0)])


def thump(rate, vol):
    """A drum: a low sine that drops as it dies."""
    n = int(0.3 * rate)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (104 - 44 * t) / rate
        out[i] = math.sin(phase) * vol * math.exp(-5.0 * t) * min(i / 80.0, 1.0)
    return out


def noise(rng, rate, dur, vol, kind, f1, f2=0.0, q=1.0):
    """A burst of hiss through a filter: a hi-hat, a rush of air."""
    n = int(dur * rate)
    hiss = filtered([rng.uniform(-1, 1) for _ in range(n)], rate, kind, f1, f2, q)
    return [v * vol * math.exp(-5.0 * i / n) * min(i / 60.0, 1.0) for i, v in enumerate(hiss)]


def tone(rate, f1, f2, dur, vol, square=False):
    """A plain note that can slide from one pitch to another."""
    n = int(dur * rate)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * (f1 * (f2 / f1) ** t) / rate
        s = math.sin(phase)
        if square:
            s = 0.6 if s > 0 else -0.6
        out[i] = s * vol * min(i / 40.0, 1.0) * (1.0 - t) ** 1.5
    return out


# ---------------------------------------------------------------- the music

def bars_of_pad(tape, zone, bars, fight):
    for b in range(bars):
        root = PROG[zone][b % 4][0]
        tape.add(b * BAR, pad(tape.rate, mf(root), BAR + 0.8, 0.07 if fight else 0.1, 260 if zone == 1 else 340), wet=0.4)
        tape.add(b * BAR, pad(tape.rate, mf(root + 7), BAR + 0.8, 0.04, 340), wet=0.4)


def calm(zone, rng):
    """Wandering: the drone, and a bell or two a bar wherever they fall. The Nave has a voice."""
    bars = 8
    tape = Tape(bars * BAR, MUSIC_SR, loop=True)
    bars_of_pad(tape, zone, bars, False)
    for b in range(bars):
        tri = PROG[zone][b % 4][1]
        for _ in range(1 if zone == 1 else rng.choice((1, 2))):
            at = b * BAR + rng.randrange(4) * BEAT + rng.random() * 0.06
            tape.add(at, bell(tape.rate, mf(rng.choice(tri) + (12 if rng.random() < 0.6 else 24)), 0.085), wet=0.5)
        if zone == 2:
            tape.add(b * BAR, choir(tape.rate, mf(tri[0]), BAR + 0.4, 0.02), wet=0.7)
    return tape


def fight(zone, rng, boss=False):
    """A fight: a running figure in the bells and a drum underneath. A boss adds the off-beats
    of the drum and the choir, which has lost a voice for every lamp already lit."""
    bars = 4
    tape = Tape(bars * BAR, MUSIC_SR, loop=True)
    bars_of_pad(tape, zone, bars, True)
    order = (0, 1, 2, 1, 0, 2, 1, 2)
    for b in range(bars):
        root, tri = PROG[zone][b % 4]
        t = b * BAR
        for i in range(8):
            tape.add(t + i * BEAT * 0.5, bell(tape.rate, mf(tri[order[i]] + 12), 0.028 if i % 4 else 0.05, 0.3), wet=0.5)
        tape.add(t, bell(tape.rate, mf(rng.choice(tri) + 24), 0.07), wet=0.5)
        for i in range(4):
            if boss or i % 2 == 0:
                tape.add(t + i * BEAT, thump(tape.rate, 0.34 if boss else 0.26))
            tape.add(t + i * BEAT + BEAT * 0.5, noise(rng, tape.rate, 0.07, 0.03, "high", 5000))
        if boss:
            voices = max(1, 3 - zone)
            tape.add(t, choir(tape.rate, mf(root + 12), BAR + 0.3, 0.075), wet=0.7)
            if voices >= 2:
                tape.add(t, choir(tape.rate, mf(tri[1]), BAR + 0.3, 0.06), wet=0.7)
            if voices >= 3:
                tape.add(t, choir(tape.rate, mf(tri[2] + 12), BAR * 0.5 + 0.2, 0.05), wet=0.7)
                tape.add(t + BAR * 0.5, choir(tape.rate, mf(tri[0] + 24), BAR * 0.5 + 0.2, 0.05), wet=0.7)
    return tape


# ---------------------------------------------------------------- the sound effects

def notes(rate, seconds, strokes, hall=0.5):
    """Bells struck one after another: (when, note, how loud, how long)."""
    tape = Tape(seconds, rate)
    for at, note, vol, long in strokes:
        tape.add(at, bell(rate, mf(note), vol, long), wet=0.5)
    return tape.mix(hall)


def fx_shot(rng):
    """A thrown harpoon or a loosed bolt: a rush of air that drops, and the snap that sent it."""
    tape = Tape(0.3, SR)
    tape.add(0, noise(rng, SR, 0.16, 0.9, "band", 2600, 700, 2.0), wet=0.2)
    tape.add(0, tone(SR, 900, 300, 0.05, 0.5))
    return tape.mix(0.3)


def fx_interrupt(rng):
    """A cast cut short: a note knocked down and a click."""
    tape = Tape(0.35, SR)
    tape.add(0, tone(SR, 700, 190, 0.14, 0.6, square=True), wet=0.3)
    tape.add(0, noise(rng, SR, 0.05, 0.6, "high", 3000))
    return tape.mix(0.4)


def fx_surge(rng):
    """A great cooldown: three bells climbing over a swell of air."""
    tape = Tape(2.2, SR)
    for i, note in enumerate((62, 69, 74)):
        tape.add(i * 0.09, bell(SR, mf(note), 0.3, 0.5), wet=0.6)
    tape.add(0, noise(rng, SR, 0.5, 0.25, "band", 500, 2400, 1.2), wet=0.5)
    return tape.mix(0.6)


def fx_fallen(rng):
    """A hero goes down: a drum and one low bell."""
    tape = Tape(2.4, SR)
    tape.add(0, thump(SR, 0.9))
    tape.add(0.02, bell(SR, mf(45), 0.4, 0.5), wet=0.6)
    return tape.mix(0.6)


def fx_wipe(rng):
    """Driven back: bells falling away, and a drum."""
    tape = Tape(3.4, SR)
    for i, note in enumerate((57, 53, 50, 45)):
        tape.add(i * 0.22, bell(SR, mf(note), 0.32, 0.6), wet=0.6)
    tape.add(0.66, thump(SR, 0.8))
    return tape.mix(0.7)


def fx_chant(rng):
    """A drowned monk singing a spell: one voice that swells. The game shifts its pitch."""
    tape = Tape(3.2, SR)
    tape.add(0, shaped(choir(SR, mf(57), 3.0, 0.5), [(0, 0.3), (0.8, 1.0), (1, 1.0)]), wet=0.5)
    return tape.mix(0.5)


def fx_deny(rng):
    """Not yet: a soft low double knock."""
    tape = Tape(0.25, SR)
    tape.add(0, tone(SR, 196, 170, 0.07, 0.6))
    tape.add(0.09, tone(SR, 165, 150, 0.08, 0.6))
    return tape.mix(0.0)


MADE = {
    # the picked sounds have nothing for these
    "shot": fx_shot,
    "interrupt": fx_interrupt,
    "surge": fx_surge,
    "fallen": fx_fallen,
    "wipe": fx_wipe,
    "chant": fx_chant,
    "ui_deny": fx_deny,
    # bells: the abbey's own voice
    "heal": lambda rng: notes(SR, 1.3, [(0, 74, 0.5, 0.25)]),
    "dispel": lambda rng: notes(SR, 1.4, [(0, 81, 0.3, 0.2), (0.06, 86, 0.3, 0.2), (0.12, 93, 0.25, 0.2)]),
    "revive": lambda rng: notes(SR, 2.6, [(0, 57, 0.3, 0.5), (0.14, 62, 0.3, 0.5), (0.28, 69, 0.35, 0.6)], 0.7),
    "toll": lambda rng: notes(SR, 4.2, [(0, 38, 0.6, 1.0), (0, 50, 0.25, 0.8)], 0.7),
    "tide_bell": lambda rng: notes(MUSIC_SR, 3.6, [(0, 50, 0.5, 0.8)], 0.6),
    "clear": lambda rng: notes(SR, 2.6, [(0, 62, 0.3, 0.5), (0.12, 65, 0.3, 0.5), (0.24, 69, 0.3, 0.5), (0.36, 74, 0.35, 0.6)], 0.6),
    "lamp": lambda rng: notes(SR, 4.6, [(0, 50, 0.4, 1.0), (0.1, 62, 0.3, 0.9), (0.2, 66, 0.3, 0.9), (0.3, 69, 0.3, 0.9), (0.4, 74, 0.3, 0.9), (0.55, 81, 0.25, 0.8)], 0.7),
}

LOOPS = {}
for _zone in range(3):
    LOOPS["calm_%d" % _zone] = lambda rng, z=_zone: calm(z, rng).mix(0.5)
    LOOPS["fight_%d" % _zone] = lambda rng, z=_zone: fight(z, rng).mix(0.5)
    LOOPS["boss_%d" % _zone] = lambda rng, z=_zone: fight(z, rng, boss=True).mix(0.5)


def save(path, samples, rate, peak):
    """Writes 16-bit mono, scaled so its loudest moment is at `peak` (1 is as loud as can be)."""
    top = max(abs(v) for v in samples) or 1.0
    k = peak / top * 32767.0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(struct.pack("<%dh" % len(samples), *(int(v * k) for v in samples)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--kits", default="~/fourfold-art/kits/audio", help="where the free sound packs are")
    ap.add_argument("names", nargs="*", help="only these sounds")
    a = ap.parse_args()
    only = set(a.names)
    unknown = only - set(PICKS) - set(MADE) - set(LOOPS)
    if unknown:
        sys.exit("No such sound: " + ", ".join(sorted(unknown)))

    kits = os.path.expanduser(a.kits)
    if not os.path.isdir(kits):
        print("no packs at %s: skipping the picked sounds" % kits)
    else:
        os.makedirs(SOUND, exist_ok=True)
        for name, (pack, file) in PICKS.items():
            if only and name not in only:
                continue
            src = os.path.join(kits, pack, file)
            if not os.path.isfile(src):
                sys.exit("missing from the packs: " + src)
            shutil.copyfile(src, os.path.join(SOUND, name + os.path.splitext(file)[1]))
            print("picked %-10s from %s" % (name, pack))

    for name, make in list(MADE.items()) + list(LOOPS.items()):
        if only and name not in only:
            continue
        loop = name in LOOPS
        rate = MUSIC_SR if loop or name == "tide_bell" else SR
        # each sound has dice of its own, so making one alone gives the same sound as making all
        samples = make(random.Random("fourfold " + name))
        path = os.path.join(MUSIC if loop or name == "tide_bell" else SOUND, name + ".wav")
        save(path, samples, rate, 0.5 if loop else 0.7)
        print("made   %-10s %5.1f s  %4d KB" % (name, len(samples) / rate, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
