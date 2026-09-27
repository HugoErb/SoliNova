"""Génère les effets sonores de SoliNova (WAV mono 44,1 kHz, 16 bits).

Sons synthétisés, doux et courts, sans aucune dépendance externe :
    python tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def envelope(i, n, attack=0.004, release=None):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    if release is None:
        release = n / RATE
    r = math.exp(-t / (release / 4))
    return a * r


def tone(freq, dur, vol=0.3, harmonics=((1, 1.0), (2, 0.25), (3, 0.08)), release=None):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(s * vol * envelope(i, n, release=release or dur))
    return out


def noise_tick(dur, vol, cutoff):
    """Bruit filtré (passe-bas simple) : bruit de carte sur feutre."""
    n = int(RATE * dur)
    rnd = random.Random(7)
    out, prev = [], 0.0
    alpha = cutoff
    for i in range(n):
        x = rnd.uniform(-1, 1)
        prev = prev + alpha * (x - prev)
        out.append(prev * vol * envelope(i, n, attack=0.002))
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        start = int(o * RATE)
        for i, v in enumerate(t):
            out[start + i] += v
    return out


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767 * 0.8))
            for s in samples
        )
        w.writeframes(frames)


def main():
    write("move", noise_tick(0.07, 0.5, 0.18))
    write("flip", mix(noise_tick(0.05, 0.35, 0.35), noise_tick(0.05, 0.25, 0.12), offsets=[0, 0.025]))
    write("deal", noise_tick(0.045, 0.4, 0.25))
    write("invalid", tone(160, 0.16, 0.5, harmonics=((1, 1.0), (2, 0.1))))
    write("foundation", tone(1318.5, 0.35, 0.22, harmonics=((1, 1.0), (2, 0.18), (4, 0.05))))
    write("win", mix(*[tone(f, 0.9, 0.18) for f in (523.25, 659.25, 783.99, 1046.5)], offsets=[0, 0.11, 0.22, 0.33]))
    write("purchase", mix(tone(987.77, 0.3, 0.2), tone(1318.5, 0.45, 0.2), offsets=[0, 0.08]))
    write("level_up", mix(*[tone(f, 0.6, 0.18) for f in (587.33, 739.99, 880.0, 1174.66)], offsets=[0, 0.08, 0.16, 0.24]))
    write("achievement", mix(tone(880.0, 0.5, 0.2), tone(1318.5, 0.7, 0.2), offsets=[0, 0.12]))


if __name__ == "__main__":
    main()
