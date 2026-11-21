#!/usr/bin/env python3
"""Suara baru v0.0.2.6: suara MATI khas tiap karakter (menggantikan yang lama), suara zombie suster,
suara loncat & skill. Jalankan: python3 tools/gen_audio3.py (numpy + scipy)."""
import os
_src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_audio.py")).read()
exec(compile(_src.split("# ---------------------------------------------------------------- ZOMBIE BIASA")[0], "gen_audio_helpers", "exec"), globals())


def tone(freq, dur, vib=0.0, breath=0.0, atk=0.05, rel=0.1, harm=(1.0, 0.3, 0.1)):
    t = t_(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(h * np.sin((k + 1) * ph) for k, h in enumerate(harm))
    if breath:
        x = x + breath * bp(noise(dur), 1500, 4500)
    return x * np.clip(t / atk, 0, 1) * np.clip((dur - t) / rel, 0, 1)

A_ = [(450, 160, 1.0), (1100, 220, 0.7), (2400, 400, 0.25)]
U_ = [(330, 120, 1.0), (850, 200, 0.6), (2300, 400, 0.2)]
O_ = [(550, 150, 1.0), (900, 180, 0.8), (2500, 400, 0.2)]
AA_ = [(800, 200, 1.0), (1250, 250, 0.7), (2600, 400, 0.25)]
I_ = [(300, 90, 1.0), (2200, 250, 0.8), (3000, 300, 0.4)]
L_U = [(260, 100, 1.0), (620, 160, 0.8), (1800, 300, 0.15)]
L_O = [(380, 110, 1.0), (700, 150, 0.9), (1900, 300, 0.12)]
L_A = [(560, 130, 1.0), (950, 170, 0.8), (2000, 300, 0.15)]

# ---- MATI zombie biasa: jeritan melengking yang pecah lalu terbatuk, badan roboh
scream = voice(1.0, [(0, 300), (0.15, 520), (0.6, 380), (1, 90)], [(0, AA_), (0.5, I_), (1, U_)], rough=0.6, rough_hz=70, breath=0.3, atk=0.02, rel=0.4)
cough = bp(noise(0.5), 200, 1100) * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * t_(0.5))) * np.linspace(1, 0, int(SR * 0.5))
fall = lp(noise(0.3), 500) * env_ad(int(SR * 0.3), 0.004, 0.08) + 0.8 * thump(0.3, 120, 40, 0.1)
save("z_die.wav", mix((0.0, scream), (0.7, cough * 0.5), (1.1, fall * 0.8)))
rattle = voice(1.3, [(0, 170), (0.4, 120), (1, 40)], [(0, A_), (1, O_)], rough=0.9, rough_hz=9, breath=0.5, atk=0.05, rel=0.6)
save("z_die_b.wav", mix((0.0, rattle), (1.0, fall * 0.8)))

# ---- MATI zombie gendut: lenguh sangat dalam, tanah bergetar
bell = voice(2.2, [(0, 60), (0.25, 95), (1, 24)], [(0, L_O), (0.5, L_A), (1, L_U)], rough=0.7, rough_hz=11, breath=0.4, vib=0.03, atk=0.1, rel=1.0)
quake = lp(noise(1.2), 120) * 2.5 * np.linspace(1, 0, int(SR * 1.2))
slam = thump(0.8, 70, 22, 0.3) * 2.0 + lp(noise(0.8), 250) * env_ad(int(SR * 0.8), 0.004, 0.2)
save("g_die.wav", mix((0.0, bell * 0.8), (0.3, quake * 0.5), (1.5, slam)))
save("g_die_b.wav", mix((0.0, voice(1.6, [(0, 80), (1, 30)], [(0, L_A), (1, L_U)], rough=0.9, rough_hz=8, breath=0.5, atk=0.05, rel=0.8) * 0.8), (1.1, slam)))

# ---- MATI samurai: kiai terakhir, napas habis, pedang jatuh
kiai = voice(0.7, [(0, 190), (0.3, 230), (1, 95)], [(0, AA_), (1, O_)], rough=0.4, rough_hz=60, breath=0.3, atk=0.02, rel=0.3)
sword = ring(0.9, [2200, 3300, 4700], 0.25) * 0.35
save("s_die.wav", mix((0.0, kiai), (0.9, lp(noise(0.5), 700) * np.linspace(0.5, 0, int(SR * 0.5))), (1.3, sword), (1.3, thump(0.3, 100, 40, 0.1))))

# ---- ZOMBIE SUSTER: suara wanita, merintih tinggi dan bergetar
def suster_groan(f=330, dur=1.2):
    return voice(dur, [(0, f), (0.35, f * 1.25), (1, f * 0.8)], [(0, I_), (0.5, AA_), (1, A_)], rough=0.3, rough_hz=30, breath=0.4, vib=0.06, atk=0.12, rel=0.4)

save("n_groan_0.wav", suster_groan(330, 1.2))
save("n_groan_1.wav", suster_groan(380, 0.9))
cl = whoosh(0.3, 2200, 6000, 0.35) * 0.7
hiss = voice(0.5, [(0, 420), (0.4, 560), (1, 300)], [(0, I_), (1, AA_)], rough=0.6, rough_hz=70, breath=0.5, atk=0.03, rel=0.2)
save("n_attack.wav", mix((0.0, cl), (0.02, hiss)))
save("n_hurt.wav", voice(0.45, [(0, 480), (0.2, 620), (1, 330)], [(0, I_), (1, AA_)], rough=0.35, rough_hz=50, breath=0.3, atk=0.02, rel=0.2))
nd = voice(1.6, [(0, 520), (0.2, 600), (1, 160)], [(0, I_), (0.5, AA_), (1, U_)], rough=0.4, rough_hz=40, breath=0.4, vib=0.08, atk=0.03, rel=0.7)
save("n_die.wav", mix((0.0, nd), (0.9, bp(noise(0.7), 200, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 12 * t_(0.7))) * np.linspace(0.6, 0, int(SR * 0.7)) * 0.5), (1.4, fall * 0.6)))
# skill kabut: desis panjang + paduan suara menyeramkan
mist = whoosh(1.4, 500, 3500, 0.5) * 0.7
choir = sum(tone(f, 1.4, vib=0.01, breath=0.1, atk=0.4, rel=0.5) for f in (220, 261.6, 311.1)) * 0.25
save("n_skill.wav", mix((0.0, mist), (0.1, choir)))
save("n_step.wav", lp(noise(0.12), 900) * env_ad(int(SR * 0.12), 0.003, 0.03) * 0.5)

# ---- LONCAT / mendarat
for key, f in (("z", 160), ("g", 80), ("n", 220), ("s", 140)):
    j = whoosh(0.2, 400, 1800 if key != "g" else 700, 0.5) * 0.4 + voice(0.2, [(0, f), (1, f * 1.4)], [(0, A_), (1, O_)], rough=0.4, rough_hz=40, breath=0.3, atk=0.02, rel=0.1) * 0.5
    save("%s_jump.wav" % key, j)
save("land.wav", thump(0.2, 120, 45, 0.07) + 0.4 * lp(noise(0.2), 600) * env_ad(int(SR * 0.2), 0.003, 0.05))
