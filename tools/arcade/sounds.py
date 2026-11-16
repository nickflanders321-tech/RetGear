"""Waypath+ card sounds: synthesised from scratch (sine, noise, envelopes), so they are ours.
Output: Media/Sounds/*.ogg (mono, 44.1 kHz).  Needs numpy, scipy and ffmpeg.
Run: python3 tools/arcade/sounds.py
"""
import os, subprocess, sys, tempfile, wave
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "Media", "Sounds")
rng = np.random.default_rng(11)

def t_(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, d=0.2, shape=3.0):
    t = np.arange(n) / SR
    e = np.exp(-t / d * shape)
    att = np.clip(t / a, 0, 1)
    return e * att
def sine(f, d, amp=1.0, decay=0.3, a=0.004, vib=0.0, vf=5.0):
    t = t_(d)
    ph = 2 * np.pi * f * t + (vib * np.sin(2 * np.pi * vf * t) if vib else 0)
    return amp * np.sin(ph) * env(len(t), a, decay)
def bell(f, d=0.8, amp=1.0, decay=0.35):
    # inharmonic partials make a bell
    out = sine(f, d, amp, decay)
    for m, g, dd in ((2.76, 0.5, 0.6), (5.4, 0.25, 0.4), (8.93, 0.12, 0.3)):
        out += sine(f * m, d, amp * g, decay * dd)
    return out
def noise(d, amp=1.0, decay=0.1, a=0.002, band=None):
    n = int(SR * d)
    x = rng.standard_normal(n)
    if band:
        sos = butter(2, band, btype="bandpass", fs=SR, output="sos"); x = sosfilt(sos, x)
    return amp * x / (np.max(np.abs(x)) + 1e-9) * env(n, a, decay)
def sweep_noise(d, f0, f1, amp=1.0, decay=0.15):
    n = int(SR * d); x = rng.standard_normal(n); out = np.zeros(n)
    steps = 12
    for i in range(steps):
        a, b = int(n * i / steps), int(n * (i + 1) / steps)
        f = f0 * (f1 / f0) ** (i / (steps - 1))
        sos = butter(2, [f * 0.7, min(f * 1.4, SR / 2 - 100)], btype="bandpass", fs=SR, output="sos")
        out[a:b] = sosfilt(sos, x)[a:b]
    out = out / (np.max(np.abs(out)) + 1e-9)
    return amp * out * env(n, 0.01, decay)
def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts)
    out = np.zeros(n)
    for start, sig in parts:
        s = int(start * SR); out[s:s + len(sig)] += sig
    return out
def fade(x, ms=12):
    n = int(SR * ms / 1000); x = x.copy()
    x[-n:] *= np.linspace(1, 0, n); return x
def norm(x, peak=0.7):
    return x / (np.max(np.abs(x)) + 1e-9) * peak
def shimmer(d, amp=0.4):
    return noise(d, amp, d * 0.4, 0.05, band=[5000, 12000])
def arp(notes, step, d, amp=0.6, decay=0.35):
    return mix(*[(i * step, bell(f, d, amp, decay)) for i, f in enumerate(notes)])

C5, E5, G5, C6, E6, G6, C7 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0
SOUNDS = {
    "flip_common": lambda: mix((0, sweep_noise(0.2, 1200, 4500, 0.9, 0.07)), (0.02, noise(0.05, 0.25, 0.02, band=[2500, 7000]))),
    "flip_rare": lambda: mix((0, sweep_noise(0.2, 1200, 4500, 0.8, 0.07)), (0.07, bell(C6, 0.7, 0.55, 0.3)), (0.07, bell(G6, 0.7, 0.3, 0.25))),
    "flip_holo": lambda: mix((0, sweep_noise(0.25, 1000, 5000, 0.8, 0.08)), (0.08, arp([C6, E6, G6, C7], 0.085, 0.9, 0.5, 0.4)), (0.1, shimmer(0.9, 0.35))),
    "flip_full": lambda: mix((0, sweep_noise(0.3, 800, 5500, 0.8, 0.1)), (0.05, sine(58, 1.0, 0.85, 0.35, 0.01)), (0.12, arp([C6, E6, G6, C7, E6, G6, C7], 0.075, 1.2, 0.5, 0.45)),
                              (0.15, shimmer(1.3, 0.45)), (0.55, bell(C7, 1.0, 0.35, 0.5))),
    "flip_legend": lambda: mix((0, sweep_noise(0.3, 700, 5000, 0.8, 0.1)), (0.04, sine(49, 1.4, 0.9, 0.5, 0.01)),
                                *[(0.1, sine(f, 1.6, 0.22, 0.9, 0.12, vib=2.0, vf=5.5)) for f in (C5, E5, G5, C6, 392.0)],
                                (0.35, arp([G6, C7, G6, C7], 0.11, 1.2, 0.45, 0.5)), (0.2, shimmer(1.6, 0.45))),
    "hover": lambda: mix((0, sine(300, 0.5, 0.35, 0.5, 0.12, vib=2.0, vf=6.0)), (0, sine(450, 0.5, 0.2, 0.5, 0.15, vib=2.0, vf=6.2)), (0.05, shimmer(0.4, 0.08))),
    "pick": lambda: mix((0, noise(0.06, 0.9, 0.018, band=[1500, 5000])), (0, sine(210, 0.09, 0.7, 0.03, 0.001))),
    "tear": lambda: mix((0, sweep_noise(0.45, 400, 4000, 1.0, 0.25)), (0.02, noise(0.4, 0.6, 0.18, 0.001, band=[200, 1800]))),
    "crack": lambda: mix((0, noise(0.04, 1.0, 0.01, 0.0005, band=[2000, 9000])), (0, sine(95, 0.35, 0.9, 0.12, 0.001)), (0.03, sweep_noise(0.35, 1500, 6000, 0.6, 0.12)),
                          (0.06, noise(0.3, 0.35, 0.1, 0.002, band=[3000, 9000]))),
    "deal": lambda: mix(*[(i * 0.07, sweep_noise(0.13, 1500, 5000, 0.55, 0.045)) for i in range(5)]),
    "best": lambda: mix((0, sine(130.8, 1.3, 0.45, 0.8, 0.02)), *[(0.02 * i, sine(f, 1.3, 0.28, 0.7, 0.03, vib=1.5, vf=5.0)) for i, f in enumerate((261.6, 329.6, 392.0, 523.25))],
                         (0.25, arp([C6, E6, G6, C7], 0.1, 1.1, 0.45, 0.5)), (0.3, shimmer(1.2, 0.35))),
    "reward": lambda: mix((0, arp([G5, C6, E6, G6], 0.09, 0.8, 0.5, 0.4)), (0.1, shimmer(0.8, 0.3)), (0.4, sine(196, 0.8, 0.35, 0.5, 0.05, vib=1.5))),
    "toast": lambda: mix((0, bell(G6, 0.6, 0.55, 0.3)), (0.11, bell(C7, 0.8, 0.5, 0.35))),
    # a raid boss's card: a deep roar (growling partials with a wobble, a rumble of low noise, a swell and a fall)
    "roar": lambda: roar(),
    # a raid photo is taken: a camera shutter and a little sparkle
    "shutter": lambda: mix((0, noise(0.03, 1.0, 0.01, 0.0005, band=[1500, 7000])), (0.07, noise(0.05, 0.8, 0.015, 0.0005, band=[1000, 5000])),
                           (0.12, shimmer(0.6, 0.25))),
    # a Mythic is coming: the card trembles and a sound rises under it (noise sweeping up, a tone climbing, a swell)
    "riser": lambda: riser(),
    # a Mythic lands: a deep impact, a wide major chord that swells with vibrato, a rising run of bells, a long shimmer
    "mythic": lambda: mix((0, noise(0.5, 1.0, 0.18, 0.001, band=[40, 500])), (0, sine(41, 2.2, 1.0, 0.9, 0.004)),
                          *[(0.03, sine(f, 3.0, 0.2, 1.4, 0.25, vib=2.5, vf=5.2)) for f in (130.8, 196.0, 261.6, 329.6, 392.0, 523.25)],
                          (0.2, arp([C6, E6, G6, C7, E6, G6, C7, E7], 0.07, 1.4, 0.42, 0.5)), (0.25, shimmer(2.6, 0.5)), (0.85, bell(C7, 1.8, 0.4, 0.8))),
    # The 1 Ring lands: the same, lower and grander, with a slow bell
    "ring": lambda: mix((0, noise(0.6, 1.0, 0.22, 0.001, band=[30, 400])), (0, sine(36.7, 2.6, 1.0, 1.0, 0.004)),
                        *[(0.03, sine(f, 3.4, 0.2, 1.6, 0.3, vib=2.2, vf=4.8)) for f in (110.0, 164.8, 220.0, 277.2, 329.6, 440.0)],
                        (0.2, arp([A5, Cs6, E6, A6, Cs7, E7], 0.09, 1.6, 0.42, 0.55)), (0.25, shimmer(3.0, 0.5)), (0.9, bell(A5, 2.6, 0.45, 1.0))),
    # a dungeon pack's crate: the fuse fizzes, then the crate bursts (a thump, splintering wood)
    # the Mythics' moments: a seal stamped down, a campfire's crackle, footsteps, Sixty's bell and the hourglass's sand
    "stamp": lambda: mix((0, sine(70, 0.35, 0.9, 0.12, 0.001)), (0, noise(0.08, 0.8, 0.03, 0.0005, band=[150, 1500])), (0.02, noise(0.05, 0.3, 0.02, 0.0005, band=[2000, 6000]))),
    "crackle": lambda: crackle(),
    "steps": lambda: mix(*[(0.22 * i, mix((0, noise(0.07, 0.6 - 0.04 * i, 0.03, 0.002, band=[150, 1200])), (0.01, noise(0.05, 0.25, 0.02, 0.001, band=[2000, 5000])))) for i in range(8)]),
    "sixty": lambda: mix((0, sine(65.4, 1.8, 0.8, 0.8, 0.004)), *[(0.05 * i, bell(f, 2.2, 0.35, 0.9)) for i, f in enumerate((523.25, 659.25, 783.99, 1046.5))], (0.3, shimmer(1.8, 0.4))),
    "sandfall": lambda: mix((0, noise(1.6, 0.6, 1.2, 0.3, band=[1500, 7000])), (0, sine(98, 1.6, 0.25, 1.2, 0.3, vib=3, vf=0.6)), (1.2, bell(1318.5, 1.2, 0.3, 0.5))),
    "fuse": lambda: fuse(),
    "rumble": lambda: rumble(),
    "boom": lambda: boom(),
    # a raid pack: each click is a clank on the lock; the chains snap with a ring of metal
    "clank": lambda: mix((0, noise(0.05, 0.8, 0.02, 0.0005, band=[1500, 6000])), (0, bell(392.0, 0.5, 0.5, 0.18)), (0, bell(587.3, 0.4, 0.3, 0.12))),
    "snap": lambda: mix((0, noise(0.08, 1.0, 0.03, 0.0005, band=[2000, 9000])), (0.02, bell(783.99, 1.0, 0.5, 0.4)), (0.05, bell(1174.7, 0.9, 0.35, 0.35)),
                        (0.0, sine(70, 0.5, 0.6, 0.2, 0.002))),
    # a holiday pack: the ribbon slips off and the lid pops, with sleigh-bell glints
    "giftpop": lambda: mix((0, noise(0.08, 0.6, 0.04, 0.002, band=[300, 2500])), (0.04, arp([C6, E6, G6, C7], 0.06, 0.9, 0.35, 0.4)), (0.1, shimmer(1.4, 0.3))),
    # a card climbs one print as it turns: a crackle, then a bright rising chime
    "upgrade": lambda: mix((0, noise(0.35, 0.4, 0.25, 0.01, band=[3000, 10000])), (0.3, arp([G6, C7, E7], 0.07, 1.0, 0.45, 0.5)), (0.35, shimmer(1.2, 0.35))),
    # one letter of the name is engraved on The 1 Ring: a tiny metal tick and a high glint
    "engrave": lambda: mix((0, noise(0.03, 0.8, 0.008, 0.0005, band=[3000, 9000])), (0.005, bell(E7, 0.35, 0.35, 0.12))),
}

A5, Cs6, E6b, A6, Cs7, E7 = 880.0, 1108.7, 1318.5, 1760.0, 2217.5, 2637.0
def crackle(d=1.6):
    n = int(SR * d); out = np.zeros(n)
    for _ in range(45):
        at = int(rng.integers(0, n - 2000)); k = noise(rng.uniform(0.005, 0.03), rng.uniform(0.2, 0.9), 0.01, 0.0002, band=[800, 6000])
        out[at:at + len(k)] += k[:n - at]
    roar_ = noise(d, 0.35, d, 0.2, band=[80, 600])
    return fade(out + roar_[:n], 60)
def fuse(d=1.9):
    # a lit fuse: a strike, then a fizzing hiss full of tiny crackles that brightens as it burns down
    n = int(SR * d)
    hiss = noise(d, 0.45, d * 3, 0.01, band=[3000, 10000])
    hiss *= np.linspace(0.7, 1.0, n)[:len(hiss)]
    crack = np.zeros(n)
    for _ in range(70):
        at = int(rng.integers(0, n - 600)); crack[at:at + 300] += noise(300 / SR, rng.uniform(0.2, 0.6), 0.002, 0.0002, band=[2500, 9000])[:300]
    strike = noise(0.12, 0.9, 0.04, 0.001, band=[800, 6000])
    out = mix((0, strike), (0.05, hiss + crack[:len(hiss)]))
    return fade(out, 40)
def rumble(d=0.9):
    # the keg strains: a low growl that swells, a creak of wood
    t = t_(d)
    up = (t / d) ** 1.5
    g = (np.sin(2 * np.pi * 48 * t + 3 * np.sin(2 * np.pi * 7 * t)) * 0.6 + noise(d, 0.6, d * 3, 0.01, band=[40, 220])[:len(t)]) * up
    creak = sine(180, 0.35, 0.3, 0.2, 0.05, vib=25, vf=9)
    return mix((0, g), (0.3, creak))
def boom():
    # the keg goes up: a sharp crack, a deep thump that rolls on, a roar of fire, then staves and hoops landing
    crack_ = noise(0.05, 1.0, 0.012, 0.0003, band=[1500, 9000])
    thump = mix((0, sine(42, 1.6, 1.0, 0.55, 0.002)), (0, sine(64, 0.9, 0.6, 0.3, 0.002)))
    roar_ = noise(1.6, 1.0, 0.55, 0.004, band=[40, 700])
    hiss = noise(1.2, 0.35, 0.4, 0.02, band=[1500, 6000])
    parts = [(0, crack_), (0, thump), (0.01, roar_), (0.05, hiss)]
    for k in range(7):   # wood clattering down
        parts.append((0.45 + k * 0.09 + rng.uniform(0, 0.05), mix((0, noise(0.06, 0.5, 0.025, 0.0005, band=[400, 2500])), (0, sine(rng.uniform(180, 320), 0.08, 0.35, 0.03, 0.001)))))
    parts.append((0.62, bell(rng.uniform(900, 1100), 0.8, 0.22, 0.25)))   # a hoop rings as it lands
    return mix(*parts)
def riser(d=1.3):
    t = t_(d)
    up = (t / d) ** 2
    f = 110 * 2 ** (2.2 * t / d)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.35 + np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.2
    hiss = sweep_noise(d, 500, 9000, 1.0, d * 2) * 0.5
    return (tone + hiss[:len(t)]) * up

def roar(d=1.7):
    t = t_(d)
    swell = np.clip(t / 0.25, 0, 1) * np.exp(-np.clip(t - 0.6, 0, None) * 2.6)
    f = 62 + 30 * np.exp(-((t - 0.45) / 0.35) ** 2) + 4 * np.sin(2 * np.pi * 7.5 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = sum(np.sin(ph * k + k) / k ** 0.8 for k in range(1, 9))
    growl = tone * (1 + 0.6 * np.sin(2 * np.pi * 23 * t))          # the rasp
    rumble = noise(d, 1.0, d, 0.08, band=[60, 400])
    breath = noise(d, 0.5, d * 0.6, 0.15, band=[600, 2500])
    return norm(growl, 0.8) * swell + rumble * swell * 0.55 + breath * swell * 0.25

def write(name, x):
    x = fade(norm(x))
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
        os.makedirs(OUT, exist_ok=True)
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    print(f"{name:12s} {len(x)/SR:4.2f}s  {os.path.getsize(dst)//1024} KB")

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, fn in SOUNDS.items():
        if not only or name in only: write(name, fn())
