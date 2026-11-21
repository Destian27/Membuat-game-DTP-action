#!/usr/bin/env python3
"""Generator suara & musik Crisis Action DTP v0.0.2.4 (hasil sintesis, tanpa aset luar).
Jalankan:  python3 tools/gen_audio.py   (butuh numpy + scipy)
Hasil: assets/sfx/*.wav  -- timpa file dengan nama sama kalau mau ganti suara sendiri.
"""
import os
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) + 1e-9
    x = x / m * peak
    wavfile.write(os.path.join(OUT, name), SR, (x * 32767).astype(np.int16))
    print("ok", name, "%.2fs" % (len(x) / SR))


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def bp(x, lo, hi, order=2):
    hi = min(hi, SR / 2 - 100)
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, fc, order=2):
    sos = signal.butter(order, fc, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, fc, order=2):
    sos = signal.butter(order, fc, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def env_ad(n, atk, dec_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(atk, 1e-4), 0, 1)
    return a * np.exp(-t / dec_tau)


def curve(n, pts):
    """interpolasi linear nilai pts=[(waktu_0..1, nilai), ...] sepanjang n sampel"""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return np.interp(np.linspace(0, 1, n), xs, ys)


def voice(dur, f0_pts, formants_pts, rough=0.0, rough_hz=40.0, breath=0.15, vib=0.0, atk=0.05, rel=0.2, shape=1.0):
    """Suara 'vokal' sintetis: sumber gigi-gergaji + filter formant yang bergeser.
    formants_pts: list [(waktu, [(f,bw,gain),...]), ...] jumlah formant sama."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = curve(n, f0_pts)
    if vib > 0:
        f0 = f0 * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    ph = 2 * np.pi * np.cumsum(f0) / SR
    src = signal.sawtooth(ph) * shape + 0.3 * np.sin(ph)
    src += breath * rng.standard_normal(n)
    if rough > 0:
        src = src * (1 - rough + rough * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rough_hz * t + 0.3 * np.sin(2 * np.pi * 7 * t)))))
    # filter formant: pecah jadi blok pendek agar formant bisa bergeser
    nf = len(formants_pts[0][1])
    out = np.zeros(n)
    blocks = 24
    edges = np.linspace(0, n, blocks + 1).astype(int)
    times = [p[0] for p in formants_pts]
    for b in range(blocks):
        a, e = edges[b], edges[b + 1]
        pos = (a + e) / 2 / n
        seg = np.zeros(e - a)
        for k in range(nf):
            fs = [p[1][k][0] for p in formants_pts]
            bws = [p[1][k][1] for p in formants_pts]
            gs = [p[1][k][2] for p in formants_pts]
            f = np.interp(pos, times, fs)
            bw = np.interp(pos, times, bws)
            g = np.interp(pos, times, gs)
            lo = max(f - bw / 2, 40)
            hi = f + bw / 2
            sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos")
            # filter seluruh sinyal blok dgn sedikit konteks supaya tidak klik
            c0 = max(a - 400, 0)
            seg += g * signal.sosfilt(sos, src[c0:e])[a - c0:]
        out[a:e] = seg
    # envelope
    e_ = np.clip(t / atk, 0, 1) * np.clip((dur - t) / rel, 0, 1)
    return out * e_


def thump(dur, f_start, f_end, tau):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f_end + (f_start - f_end) * np.exp(-t / (tau * 0.5))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / tau)


def whoosh(dur, f_lo, f_hi, peak_pos=0.4, q=1.0):
    n = int(SR * dur)
    x = noise(dur)
    out = np.zeros(n)
    blocks = 20
    edges = np.linspace(0, n, blocks + 1).astype(int)
    for b in range(blocks):
        a, e = edges[b], edges[b + 1]
        pos = (a + e) / 2 / n
        fc = f_lo + (f_hi - f_lo) * pos
        sos = signal.butter(2, [fc * 0.7, fc * 1.4], btype="band", fs=SR, output="sos")
        c0 = max(a - 300, 0)
        out[a:e] = signal.sosfilt(sos, x[c0:e])[a - c0:]
    t = np.arange(n) / SR / dur
    shape = np.exp(-((t - peak_pos) ** 2) / (2 * 0.18 ** 2))
    return out * shape


def ring(dur, freqs, tau, gains=None):
    t = t_(dur)
    x = np.zeros_like(t)
    for i, f in enumerate(freqs):
        g = 1.0 if gains is None else gains[i]
        x += g * np.sin(2 * np.pi * f * t) * np.exp(-t / (tau / (1 + 0.4 * i)))
    return x


def mix(*parts, length=None):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts) if length is None else int(length * SR)
    out = np.zeros(n)
    for off, x in parts:
        s = int(off * SR)
        e = min(s + len(x), n)
        out[s:e] += x[: e - s]
    return out


# ---------------------------------------------------------------- ZOMBIE BIASA (kurus, cepat, serak)
A_ = [(450, 160, 1.0), (1100, 220, 0.7), (2400, 400, 0.25)]
U_ = [(330, 120, 1.0), (850, 200, 0.6), (2300, 400, 0.2)]
O_ = [(550, 150, 1.0), (900, 180, 0.8), (2500, 400, 0.2)]
AA_ = [(800, 200, 1.0), (1250, 250, 0.7), (2600, 400, 0.25)]


def zombie_groan(seed_shift=0.0, dur=1.1):
    f = 105 + seed_shift
    x = voice(dur, [(0, f), (0.3, f * 1.1), (1, f * 0.72)],
              [(0, U_), (0.45, AA_), (1, O_)], rough=0.55, rough_hz=38, breath=0.25, vib=0.03, atk=0.12, rel=0.35)
    x += 0.35 * bp(noise(dur), 1200, 3500) * np.clip(t_(dur) / 0.3, 0, 1) * np.clip((dur - t_(dur)) / 0.3, 0, 1)
    return x


save("z_groan_0.wav", zombie_groan(0.0, 1.1))
save("z_groan_1.wav", zombie_groan(18.0, 0.85))
save("z_groan_2.wav", zombie_groan(-12.0, 1.35))

# serang: cakaran (whoosh + sobekan) + geraman pendek
claw = whoosh(0.3, 1800, 5000, 0.35) * 0.7 + 0.25 * hp(noise(0.3), 3000) * env_ad(int(SR * 0.3), 0.01, 0.07)
snarl = voice(0.5, [(0, 210), (0.3, 260), (1, 170)], [(0, A_), (1, AA_)], rough=0.7, rough_hz=55, breath=0.35, atk=0.03, rel=0.2)
save("z_attack.wav", mix((0.0, claw), (0.02, snarl)))

# kena: teriak pendek "aargh"
save("z_hurt.wav", voice(0.42, [(0, 230), (0.2, 300), (1, 150)], [(0, AA_), (1, O_)], rough=0.5, rough_hz=45, breath=0.3, atk=0.02, rel=0.18))

# mati: erangan menurun + gorgle basah + jatuh
die = voice(1.5, [(0, 140), (0.25, 150), (1, 45)], [(0, AA_), (0.4, A_), (1, U_)], rough=0.8, rough_hz=17, breath=0.4, vib=0.05, atk=0.03, rel=0.6)
gurgle = bp(noise(1.0), 250, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t_(1.0))) * np.linspace(1, 0, int(SR * 1.0))
fall = lp(noise(0.3), 400) * env_ad(int(SR * 0.3), 0.005, 0.08) + 0.8 * thump(0.3, 110, 40, 0.1)
save("z_die.wav", mix((0.0, die), (0.5, gurgle * 0.5), (1.1, fall * 0.8)))

# ---------------------------------------------------------------- ZOMBIE GENDUT (besar, berat, dalam)
L_U = [(260, 100, 1.0), (620, 160, 0.8), (1800, 300, 0.15)]
L_O = [(380, 110, 1.0), (700, 150, 0.9), (1900, 300, 0.12)]
L_A = [(560, 130, 1.0), (950, 170, 0.8), (2000, 300, 0.15)]


def gendut_groan(f=58, dur=1.5):
    x = voice(dur, [(0, f), (0.35, f * 1.25), (1, f * 0.62)], [(0, L_U), (0.5, L_A), (1, L_O)],
              rough=0.6, rough_hz=24, breath=0.3, vib=0.025, atk=0.2, rel=0.5)
    rumble = lp(noise(dur), 160) * 2.0 * np.clip(t_(dur) / 0.4, 0, 1) * np.clip((dur - t_(dur)) / 0.5, 0, 1)
    return x + 0.8 * rumble


save("g_groan_0.wav", gendut_groan(58, 1.5))
save("g_groan_1.wav", gendut_groan(48, 1.8))

# pukul: ayunan berat + hantaman keras + dengusan
swing = whoosh(0.35, 250, 900, 0.5) * 0.8
slam = thump(0.45, 130, 38, 0.14) + 0.6 * lp(noise(0.45), 500) * env_ad(int(SR * 0.45), 0.003, 0.07)
grunt = voice(0.35, [(0, 90), (1, 65)], [(0, L_A), (1, L_O)], rough=0.5, rough_hz=30, breath=0.3, atk=0.03, rel=0.15)
save("g_punch.wav", mix((0.0, grunt * 0.9), (0.08, swing), (0.3, slam * 1.4)))

save("g_hurt.wav", voice(0.55, [(0, 85), (0.2, 105), (1, 60)], [(0, L_A), (1, L_O)], rough=0.55, rough_hz=28, breath=0.3, atk=0.02, rel=0.25))

gd = voice(2.0, [(0, 75), (0.3, 80), (1, 30)], [(0, L_A), (0.5, L_O), (1, L_U)], rough=0.8, rough_hz=13, breath=0.4, vib=0.04, atk=0.04, rel=0.9)
body = thump(0.6, 80, 28, 0.22) * 1.6 + lp(noise(0.6), 300) * env_ad(int(SR * 0.6), 0.004, 0.15)
save("g_die.wav", mix((0.0, gd * 0.8), (1.2, body)))

# langkah berat gendut (dipakai bot gendut saat jalan)
save("g_step.wav", thump(0.28, 95, 35, 0.09) * 1.2 + 0.4 * lp(noise(0.28), 300) * env_ad(int(SR * 0.28), 0.003, 0.05))

# ---------------------------------------------------------------- SAMURAI
# ayunan cepat: desing logam
fast = whoosh(0.28, 1200, 6500, 0.4) * 0.9 + 0.12 * ring(0.28, [2600, 3900, 5200], 0.06)
save("s_swing.wav", fast)

# tebasan berat: kiai + desing panjang + dentang
S_A = [(700, 140, 1.0), (1220, 200, 0.7), (2600, 400, 0.2)]
S_O = [(500, 120, 1.0), (900, 160, 0.8), (2400, 400, 0.15)]
kiai = voice(0.38, [(0, 150), (0.2, 175), (1, 120)], [(0, S_A), (1, S_O)], rough=0.25, rough_hz=35, breath=0.4, atk=0.015, rel=0.15, vib=0.02)
heavy = whoosh(0.55, 500, 3500, 0.45) * 1.0 + 0.2 * ring(0.55, [1800, 2700, 4100], 0.14)
save("s_heavy.wav", mix((0.0, kiai * 1.0), (0.12, heavy)))

# kena: dengusan pria
save("s_hurt.wav", voice(0.32, [(0, 125), (0.25, 140), (1, 95)], [(0, S_A), (1, S_O)], rough=0.2, rough_hz=40, breath=0.35, atk=0.015, rel=0.15))

# mati: erangan jatuh + pedang berdenting ke lantai
sd = voice(1.0, [(0, 130), (0.3, 120), (1, 55)], [(0, S_A), (0.5, S_O), (1, [(380, 110, 1.0), (700, 150, 0.8), (2000, 300, 0.1)])],
           rough=0.35, rough_hz=20, breath=0.4, vib=0.04, atk=0.02, rel=0.45)
clang = ring(1.0, [1250, 1870, 2950, 4200], 0.35, [1, 0.6, 0.4, 0.25]) * 0.5
clang2 = ring(0.7, [1100, 1650, 2700], 0.25, [1, 0.6, 0.3]) * 0.35
fall = lp(noise(0.3), 500) * env_ad(int(SR * 0.3), 0.004, 0.07) + thump(0.3, 100, 45, 0.09)
save("s_die.wav", mix((0.0, sd), (0.55, fall * 0.9), (0.62, clang), (0.95, clang2)))

# cabut pedang (saat berubah jadi samurai)
scrape = bp(noise(0.7), 3000, 7500) * np.clip(t_(0.7) / 0.5, 0, 1) ** 1.5 * np.clip((0.7 - t_(0.7)) / 0.1, 0, 1)
scrape *= (0.7 + 0.3 * np.sin(2 * np.pi * 70 * t_(0.7)))
shing = ring(0.9, [2400, 3600, 4800, 6100], 0.5, [1, 0.7, 0.5, 0.3])
save("s_unsheathe.wav", mix((0.0, scrape * 0.7), (0.45, shing * 0.55)))

# ---------------------------------------------------------------- UMUM
# peluru kena zombie (daging basah)
save("flesh_hit.wav", lp(noise(0.22), 1800) * env_ad(int(SR * 0.22), 0.002, 0.05) + 0.9 * thump(0.22, 190, 60, 0.07))
# benturan cakar/pukulan mengenai target
save("claw_hit.wav", bp(noise(0.25), 500, 3000) * env_ad(int(SR * 0.25), 0.002, 0.06) + 0.7 * thump(0.25, 150, 55, 0.08))
save("slash_hit.wav", 0.8 * hp(noise(0.3), 1500) * env_ad(int(SR * 0.3), 0.001, 0.05) + 0.5 * ring(0.3, [2200, 3300], 0.1) + 0.5 * thump(0.3, 140, 60, 0.07))

# jeritan manusia terinfeksi
scream = voice(1.1, [(0, 380), (0.25, 620), (0.7, 700), (1, 420)], [(0, [(750, 150, 1.0), (1300, 200, 0.7), (2800, 400, 0.3)]), (1, [(600, 150, 1.0), (1100, 200, 0.7), (2700, 400, 0.3)])],
               rough=0.3, rough_hz=60, breath=0.25, vib=0.05, atk=0.04, rel=0.3)
save("infect.wav", scream)

# raungan Induk Zombie (muncul / awal ronde)
roar = voice(1.9, [(0, 70), (0.2, 95), (0.7, 85), (1, 40)], [(0, L_A), (0.5, A_), (1, L_O)], rough=0.7, rough_hz=32, breath=0.45, vib=0.03, atk=0.1, rel=0.7)
roar += 0.8 * lp(noise(1.9), 220) * np.clip(t_(1.9) / 0.3, 0, 1) * np.clip((1.9 - t_(1.9)) / 0.7, 0, 1)
save("z_roar.wav", roar)

# ---------------------------------------------------------------- MUSIK
def loop_xfade(x, ov=1.2):
    o = int(SR * ov)
    head = x[:o].copy()
    tail = x[-o:].copy()
    w = np.linspace(0, 1, o)
    blend = head * w + tail * (1 - w)
    return np.concatenate([blend, x[o:-o]])


def pluck(freq, dur, decay=0.996):
    """Karplus-Strong (kayak koto / gitar)"""
    n = int(SR * dur)
    N = int(SR / freq)
    buf = rng.uniform(-1, 1, N)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % N]
        buf[i % N] = decay * 0.5 * (buf[i % N] + buf[(i + 1) % N])
    return out


def tone(freq, dur, vib=0.0, breath=0.0, atk=0.05, rel=0.1, harm=(1.0, 0.3, 0.1)):
    t = t_(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(h * np.sin((k + 1) * ph) for k, h in enumerate(harm))
    if breath:
        x = x + breath * bp(noise(dur), 1500, 4500)
    return x * np.clip(t / atk, 0, 1) * np.clip((dur - t) / rel, 0, 1)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- musik mode Zombie: gelap, denyut jantung, drone, jeritan biola jauh
BPM = 70
beat = 60.0 / BPM
beats = 36
dur = beats * beat
n = int(SR * dur)
tt = np.arange(n) / SR
m = np.zeros(n)
# drone rendah (A1 + Bb1 bergesekan) dengan filter menyapu pelan
for f, g in [(55.0, 1.0), (58.27, 0.6), (82.4, 0.35)]:
    ph = 2 * np.pi * f * tt
    m += g * (signal.sawtooth(ph + 0.4 * np.sin(2 * np.pi * 0.11 * tt)) * 0.5 + np.sin(ph) * 0.6)
m = lp(m, 380)
m *= 0.55 + 0.45 * np.sin(2 * np.pi * (1 / (beat * 8)) * tt - 1.0)
# pad dissonan tinggi
pad = np.zeros(n)
for f, g in [(220.0, 1.0), (233.08, 0.9), (329.6, 0.6)]:
    pad += g * np.sin(2 * np.pi * f * tt + 2 * np.sin(2 * np.pi * 0.2 * tt))
pad = lp(pad, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * (1 / (beat * 12)) * tt + 2.0)) * 0.10
m += pad
# denyut jantung "lub-dub" tiap 2 beat
for b in range(0, beats, 2):
    t0 = b * beat
    for off, amp in [(0.0, 1.0), (0.32, 0.7)]:
        h = thump(0.35, 85, 38, 0.1) * amp * 1.3
        s = int((t0 + off) * SR)
        m[s:s + len(h)] += h[: n - s]
# jeritan biola tinggi yang jauh, acak tapi tetap (seed tetap)
for t0, f_from, f_to, d in [(5.0, 1400, 1180, 2.2), (13.3, 1750, 1500, 1.8), (21.0, 1250, 1050, 2.6), (27.4, 1600, 1330, 2.0)]:
    nn = int(SR * d)
    tm = np.arange(nn) / SR
    f = np.linspace(f_from, f_to, nn)
    ph = 2 * np.pi * np.cumsum(f * (1 + 0.012 * np.sin(2 * np.pi * 5.8 * tm))) / SR
    v = (np.sin(ph) + 0.35 * np.sin(2 * ph)) * np.sin(np.pi * tm / d) ** 2 * 0.07
    s = int(t0 * SR)
    m[s:s + nn] += v[: n - s]
# gesekan logam / ketukan jauh
for t0 in [9.4, 18.2, 24.6, 30.0]:
    kn = bp(noise(1.0), 700, 2200) * env_ad(int(SR * 1.0), 0.01, 0.18) * 0.12 + ring(1.0, [880, 1330], 0.5, [0.05, 0.03])
    s = int(t0 * SR)
    m[s:s + len(kn)] += kn[: n - s]
m = loop_xfade(m, 1.2)
save("music_zombie.wav", m, peak=0.7)

# --- musik Samurai: taiko + shakuhachi + koto, tangga Hirajoshi (D E F A Bb)
BPM2 = 96
beat2 = 60.0 / BPM2
bars = 8
dur2 = bars * 4 * beat2
n2 = int(SR * dur2)
s_ = np.zeros(n2)


def put(x, t0, g=1.0):
    st = int(t0 * SR)
    if st >= n2:
        return
    e = min(st + len(x), n2)
    s_[st:e] += g * x[: e - st]


def taiko(big=True):
    d = 0.7 if big else 0.35
    return (thump(d, 120 if big else 160, 42 if big else 70, 0.18 if big else 0.08) * 1.2
            + lp(noise(d), 700) * env_ad(int(SR * d), 0.002, 0.05) * 0.5)


for bar in range(bars):
    b0 = bar * 4 * beat2
    put(taiko(True), b0, 1.0)
    put(taiko(True), b0 + 2 * beat2, 0.85)
    put(taiko(False), b0 + 1.5 * beat2, 0.5)
    put(taiko(False), b0 + 3 * beat2, 0.55)
    put(taiko(False), b0 + 3.5 * beat2, 0.45)
    if bar % 4 == 3:  # gulungan drum di akhir frasa
        for k in range(8):
            put(taiko(False), b0 + 3 * beat2 + k * beat2 / 8, 0.3 + 0.06 * k)
    # klik kayu (tsuzumi) di beat lemah
    for k in (1, 3):
        put(bp(noise(0.08), 1500, 3500) * env_ad(int(SR * 0.08), 0.001, 0.02) * 0.25, b0 + k * beat2)

# melodi shakuhachi, Hirajoshi D: D4=62 E4=64 F4=65 A4=69 Bb4=70 D5=74
mel = [(62, 2), (65, 1), (64, 1), (62, 2), (70, 2), (69, 2), (65, 2), (64, 2), (62, 4),
       (69, 1.5), (70, 0.5), (69, 1), (65, 1), (64, 2), (65, 2), (62, 2), (74, 3), (70, 1), (69, 2), (65, 1), (64, 1), (62, 4)]
t0 = 0.0
for midi_n, bt in mel:
    d = bt * beat2
    if t0 + d > dur2:
        break
    put(tone(midi(midi_n), d * 0.97, vib=0.006, breath=0.12, atk=0.08, rel=0.12, harm=(1.0, 0.18, 0.06)), t0, 0.28)
    t0 += d

# koto: arpeggio
arp = [50, 57, 62, 65, 57, 62, 64, 62]
for bar in range(bars):
    for k in range(8):
        note = arp[k] + (12 if (bar // 2) % 2 and k % 4 == 3 else 0)
        pl = pluck(midi(note), 0.9, 0.995)
        pl = lp(pl, 4500)
        put(pl, bar * 4 * beat2 + k * beat2 / 2 + (0 if bar % 2 == 0 else 0), 0.22)

# bass drone D
tt2 = np.arange(n2) / SR
drone = lp(signal.sawtooth(2 * np.pi * 73.4 * tt2) * 0.4 + np.sin(2 * np.pi * 36.7 * tt2), 300) * 0.28
s_ += drone
s_ = loop_xfade(s_, 0.6)
save("music_samurai.wav", s_, peak=0.8)

print("selesai.")
