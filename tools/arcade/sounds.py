"""Waypath+ card sounds: synthesised from scratch (sine, noise, envelopes), so they are ours.
Output: Media/Sounds/*.ogg (mono, 44.1 kHz).  Needs numpy, scipy and ffmpeg.
Run: python3 tools/arcade/sounds.py
"""
import os, subprocess, tempfile, wave
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
}

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
    for name, fn in SOUNDS.items():
        write(name, fn())
