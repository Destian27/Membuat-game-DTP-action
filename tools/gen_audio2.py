#!/usr/bin/env python3
"""Suara tambahan v0.0.2.5: skill (lari, perisai, tebasan besar), enhance, beli, pasang senjata, Deagle.
Jalankan:  python3 tools/gen_audio2.py   (butuh numpy + scipy). Hasil: assets/sfx/*.wav
"""
import os
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(11)


def T(d):
    return np.arange(int(SR * d)) / SR


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    wavfile.write(os.path.join(OUT, name), SR, (x * 32767).astype(np.int16))
    print("ok", name, "%.2fs" % (len(x) / SR))


def bp(x, lo, hi):
    sos = signal.butter(2, [lo, min(hi, SR / 2 - 100)], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, fc):
    return signal.sosfilt(signal.butter(2, fc, btype="low", fs=SR, output="sos"), x)


def env(n, atk, tau):
    t = np.arange(n) / SR
    return np.clip(t / max(atk, 1e-4), 0, 1) * np.exp(-t / tau)


def sweep(d, f0, f1, shape="sine"):
    t = T(d)
    f = np.linspace(f0, f1, len(t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) if shape == "sine" else signal.sawtooth(ph)


# --- skill lari: desis angin naik + denyut rendah
t = T(0.9)
n = rng.standard_normal(len(t))
sweep_f = np.linspace(500, 3200, len(t))
whoosh = np.zeros(len(t))
for i in range(0, len(t), 512):
    j = min(i + 512, len(t))
    fc = float(sweep_f[i])
    whoosh[i:j] = bp(n[max(0, i - 256):j], fc * 0.6, fc * 1.4)[-(j - i):]
whoosh *= np.sin(np.pi * np.linspace(0, 1, len(t))) ** 1.2
thump = sweep(0.9, 140, 50) * env(len(t), 0.005, 0.18)
save("skill_run.wav", whoosh * 0.9 + thump * 0.8)

# --- perisai nyala: dengung logam naik + kilau
t = T(1.1)
hum = sweep(1.1, 90, 220, "saw") * 0.4 + sweep(1.1, 180, 440) * 0.5
hum = lp(hum, 1400) * env(len(t), 0.05, 0.6)
shim = (np.sin(2 * np.pi * 1760 * t) + 0.6 * np.sin(2 * np.pi * 2640 * t)) * env(len(t), 0.01, 0.35) * 0.4
shim = np.roll(shim, int(SR * 0.18)) * (t > 0.18)
save("shield_on.wav", hum + shim)

# --- perisai habis: turun + pecah
t = T(0.7)
dn = sweep(0.7, 520, 70) * env(len(t), 0.004, 0.22)
crack = bp(rng.standard_normal(len(t)), 2500, 9000) * env(len(t), 0.001, 0.07)
save("shield_off.wav", dn * 0.7 + crack * 0.6)

# --- skill siap: ting dua nada
t = T(0.5)
a = np.sin(2 * np.pi * 988 * t) * env(len(t), 0.003, 0.12)
b = np.sin(2 * np.pi * 1319 * np.clip(t - 0.09, 0, None)) * env(len(t), 0.003, 0.2) * (t > 0.09)
save("skill_ready.wav", a * 0.7 + b)

# --- tebasan besar samurai: desing logam panjang + hantaman berat
t = T(0.8)
sw = bp(rng.standard_normal(len(t)), 1200, 8000) * np.sin(np.pi * np.clip(t / 0.35, 0, 1)) * (t < 0.35)
ring = (np.sin(2 * np.pi * 2400 * t) * 0.5 + np.sin(2 * np.pi * 3610 * t) * 0.3) * env(len(t), 0.3, 0.25) * (t > 0.3)
boom = sweep(0.8, 120, 40) * env(len(t), 0.002, 0.2) * (t > 0.28)
boom = np.roll(boom, int(SR * 0.28)) if False else boom
save("slash_big.wav", sw * 0.8 + ring * 0.35 + boom * 0.9)

# --- Deagle: letusan berat
t = T(0.55)
crack = rng.standard_normal(len(t)) * env(len(t), 0.0005, 0.03)
body = sweep(0.55, 190, 45) * env(len(t), 0.001, 0.12)
tail = lp(rng.standard_normal(len(t)), 900) * env(len(t), 0.002, 0.16)
save("deagle.wav", crack * 0.9 + body * 1.2 + tail * 0.5)

# --- enhance berhasil: palu + kilau naik
t = T(1.0)
hit = bp(rng.standard_normal(len(t)), 800, 4000) * env(len(t), 0.0008, 0.05) + sweep(1.0, 220, 90) * env(len(t), 0.001, 0.08)
chime = np.zeros(len(t))
for k, f in enumerate([784, 988, 1175, 1568]):
    s = int(SR * (0.12 + 0.09 * k))
    seg = np.sin(2 * np.pi * f * T(1.0)[: len(t) - s]) * env(len(t) - s, 0.004, 0.25)
    chime[s:] += seg * 0.5
save("enhance_ok.wav", hit * 0.8 + chime)

# --- beli: koin
t = T(0.5)
c1 = np.sin(2 * np.pi * 1568 * t) * env(len(t), 0.001, 0.08)
c2 = np.sin(2 * np.pi * 2093 * np.clip(t - 0.07, 0, None)) * env(len(t), 0.001, 0.18) * (t > 0.07)
save("buy.wav", c1 * 0.6 + c2)

# --- pasang senjata: klik logam + geser
t = T(0.35)
cl = bp(rng.standard_normal(len(t)), 1500, 7000) * env(len(t), 0.0005, 0.02)
sl = bp(rng.standard_normal(len(t)), 600, 2500) * env(len(t), 0.02, 0.06) * (t < 0.15) * 0.4
cl2 = np.roll(cl, int(SR * 0.12)) * 0.8
save("equip.wav", cl + sl + cl2)
