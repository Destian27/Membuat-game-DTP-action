#!/usr/bin/env python3
"""Generator gambar Crisis Action DTP v0.0.2.6 (hasil gambar kode, tanpa aset luar).
Jalankan:  python3 tools/gen_chars.py   (butuh pillow + numpy)

Hasil:
  assets/char_zombie|char_gendut|char_samurai/  -> tambah jump_0..1 dan skill_0..1
  assets/char_suster/                           -> set lengkap (idle, walk, jump, skill, shoot, die)
  assets/portrait_biasa|gendut|suster.png       -> gambar kartu pilih zombie
  assets/zombie_hands_2..3, gendut_fists_2..3   -> tangan first-person (loncat, skill)
  assets/suster_hands_0..3                      -> tangan first-person zombie suster
Frame idle/walk/shoot/die zombie, gendut, samurai yang sudah ada TIDAK ditimpa.
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
AS = os.path.join(HERE, "..", "assets")
SS = 4
W = 256
OL = (38, 30, 30, 255)
CREAM = (240, 232, 210, 255)


class Cv:
    def __init__(s):
        s.im = Image.new("RGBA", (W * SS, W * SS), (0, 0, 0, 0))
        s.d = ImageDraw.Draw(s.im)

    def P(s, p):
        return (p[0] * SS, p[1] * SS)

    def circle(s, c, r, fill, ol=3):
        x, y = s.P(c)
        R, o = r * SS, ol * SS
        s.d.ellipse([x - R - o, y - R - o, x + R + o, y + R + o], fill=OL)
        s.d.ellipse([x - R, y - R, x + R, y + R], fill=fill)

    def ell(s, c, rx, ry, fill, ol=3):
        x, y = s.P(c)
        s.d.ellipse([x - (rx + ol) * SS, y - (ry + ol) * SS, x + (rx + ol) * SS, y + (ry + ol) * SS], fill=OL)
        s.d.ellipse([x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS], fill=fill)

    def cap(s, a, b, w, fill, ol=3):
        for col, ww in ((OL, w + 2 * ol), (fill, w)):
            s.d.line([s.P(a), s.P(b)], fill=col, width=int(ww * SS))
            r = ww * SS / 2
            for p in (a, b):
                x, y = s.P(p)
                s.d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    def poly(s, pts, fill, ol=3):
        q = [s.P(p) for p in pts]
        s.d.polygon(q, fill=fill)
        s.d.line(q + [q[0]], fill=OL, width=int(ol * 1.6 * SS), joint="curve")

    def rrect(s, c, w, h, fill, ol=2, r=6):
        x, y = s.P(c)
        s.d.rounded_rectangle([x - w * SS / 2, y - h * SS / 2, x + w * SS / 2, y + h * SS / 2], radius=r * SS, fill=fill, outline=OL, width=int(ol * SS))

    def line(s, a, b, col, w):
        s.d.line([s.P(a), s.P(b)], fill=col, width=int(w * SS))


def glow(color, center, r, alpha=120, blur=18):
    """lapisan cahaya (di belakang karakter)"""
    im = Image.new("RGBA", (W * SS, W * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x, y = center[0] * SS, center[1] * SS
    d.ellipse([x - r * SS, y - r * SS, x + r * SS, y + r * SS], fill=color[:3] + (alpha,))
    return im.filter(ImageFilter.GaussianBlur(blur * SS / 2))


def finish(c, bg=None, fg=None, alpha=1.0):
    im = c.im
    if alpha < 1.0:
        a = im.split()[3].point(lambda v: int(v * alpha))
        im.putalpha(a)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    if bg is not None:
        out = Image.alpha_composite(out, bg)
    out = Image.alpha_composite(out, im)
    if fg is not None:
        out = Image.alpha_composite(out, fg)
    return out


def down(im):
    return im.resize((W, W), Image.LANCZOS)


# ------------------------------------------------------------------ bagian tubuh bersama
def ik(S, tgt, l1, l2, side):
    """elbow untuk lengan dua ruas; tgt = (keluar, bawah) relatif bahu. side -1 kiri, +1 kanan"""
    tx, ty = side * tgt[0], tgt[1]
    d = max(math.hypot(tx, ty), 1e-3)
    d = min(d, l1 + l2 - 0.5)
    ux, uy = tx / math.hypot(tx, ty + 1e-9), ty / math.hypot(tx, ty + 1e-9)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    best = None
    for sg in (1, -1):
        ex = S[0] + ux * a + (-uy) * h * sg
        ey = S[1] + uy * a + (ux) * h * sg
        score = side * (ex - S[0]) + 0.6 * (ey - S[1])
        if best is None or score > best[0]:
            best = (score, (ex, ey))
    hand = (S[0] + ux * d, S[1] + uy * d)
    return best[1], hand, (ux, uy)


def claws(c, hand, direction, n=3, size=10, spread=0.5, base=8):
    ang = math.atan2(direction[1], direction[0])
    for i in range(n):
        a = ang + (i - (n - 1) / 2) * spread
        bx, by = hand[0] + math.cos(a) * base, hand[1] + math.sin(a) * base
        tx, ty = hand[0] + math.cos(a) * (base + size), hand[1] + math.sin(a) * (base + size)
        px, py = -math.sin(a) * 2.6, math.cos(a) * 2.6
        c.poly([(bx + px, by + py), (tx, ty), (bx - px, by - py)], CREAM, ol=1.1)


def eyes(c, cx, cy, spread, r, col, pupil=(20, 10, 10, 255)):
    for s in (-1, 1):
        c.circle((cx + s * spread, cy), r, col, ol=1.8)
        c.circle((cx + s * spread, cy), r * 0.42, pupil, ol=0)


def mouth(c, cx, cy, open_, teeth=CREAM, blood=(150, 20, 30, 255)):
    if open_ > 0.5:
        c.ell((cx, cy + 3), 11, 8, (70, 12, 16, 255), ol=2)
        c.rrect((cx, cy - 2), 18, 5, teeth, ol=1, r=2)
    else:
        c.rrect((cx, cy), 24, 8, teeth, ol=1.6, r=3)
        for k in (-6, 0, 6):
            c.line((cx + k, cy - 3), (cx + k, cy + 3), (90, 70, 60, 255), 0.8)
    c.line((cx - 11, cy + 2), (cx - 13, cy + 12), blood, 1.8)


def spiky_hair(c, cx, cy, col=(40, 50, 36, 255)):
    c.poly([(cx - 22, cy - 6), (cx - 19, cy - 24), (cx - 10, cy - 15), (cx - 4, cy - 31), (cx + 4, cy - 16),
            (cx + 12, cy - 28), (cx + 16, cy - 14), (cx + 23, cy - 8), (cx, cy - 14)], col, ol=1.6)


# ------------------------------------------------------------------ ZOMBIE BIASA
def zombie(pose):
    c = Cv()
    dy, lean = pose.get("dy", 0), pose.get("lean", 0)

    def T(x, y):
        t = max(0.0, min(1.0, (150 - y) / 110.0))
        return (x + lean * t, y + dy * (0.8 + 0.2 * t))

    knee = pose.get("knee", 0) + dy * 0.45
    fd = pose.get("foot", [(0, 0), (0, 0)])
    for i, s in enumerate((-1, 1)):
        hip = T(128 + s * 14, 150)
        foot = (128 + s * 14 + fd[i][0], 235 + fd[i][1])
        mid = ((hip[0] + foot[0]) / 2 + s * knee, (hip[1] + foot[1]) / 2)
        c.cap(hip, mid, 24, (72, 66, 58, 255))
        c.cap(mid, foot, 24, (72, 66, 58, 255))
        c.rrect((foot[0], foot[1] + 9), 34, 20, (38, 30, 30, 255), ol=1.5, r=7)
    # torso
    pts = [(96, 72), (160, 72), (160, 142), (151, 150), (144, 141), (137, 150), (128, 141), (119, 150), (112, 141), (105, 150), (96, 142)]
    c.poly([T(*p) for p in pts], (52, 84, 122, 255))
    c.line(T(108, 84), T(148, 130), (150, 20, 30, 255), 3)
    for yy, x0, x1 in ((94, 108, 142), (102, 100, 138), (110, 108, 142)):
        c.line(T(x0, yy), T(x1, yy), (96, 150, 70, 255), 2)
    # kepala
    hc = T(128, 45)
    c.circle(hc, 24, (126, 176, 96, 255))
    spiky_hair(c, hc[0], hc[1])
    eyes(c, hc[0], hc[1], 10, 6.2, (240, 215, 60, 255))
    mouth(c, hc[0], hc[1] + 14, pose.get("mouth", 0))
    # lengan
    for i, s in enumerate((-1, 1)):
        S = T(128 + s * 34, 80)
        el, hand, dr = ik(S, pose["hands"][i], 26, 24, s)
        c.cap(S, el, 14, (53, 89, 130, 255))
        c.cap(el, hand, 14, (53, 89, 130, 255))
        c.circle(hand, 9.5, (126, 176, 96, 255), ol=2.2)
        claws(c, hand, dr, n=3, size=9, spread=0.55, base=9)
    return c


def zombie_pose(name):
    P = {
        "idle_0": dict(hands=[(24, 54), (24, 54)]),
        "idle_1": dict(hands=[(28, 58), (28, 58)], dy=1),
        "walk_0": dict(hands=[(22, 46), (26, 62)], foot=[(0, -9), (0, 0)], lean=-3),
        "walk_1": dict(hands=[(24, 54), (24, 54)]),
        "walk_2": dict(hands=[(26, 62), (22, 46)], foot=[(0, 0), (0, -9)], lean=3),
        "walk_3": dict(hands=[(24, 54), (24, 54)]),
        "shoot_0": dict(hands=[(54, -28), (54, -28)], mouth=1),
        "shoot_1": dict(hands=[(-4, 24), (-4, 24)], mouth=1, lean=6, dy=4),
        # LOMPAT: jongkok lalu melayang dengan kaki ditekuk, tangan terangkat
        "jump_0": dict(hands=[(18, 62), (18, 62)], dy=18, knee=6, foot=[(-3, 0), (3, 0)]),
        "jump_1": dict(hands=[(44, -24), (44, -24)], dy=-10, knee=10, foot=[(-6, -22), (6, -16)], mouth=1),
        # SKILL lari: meraung, tangan terbuka, badan condong
        "skill_0": dict(hands=[(46, -34), (46, -34)], mouth=1, lean=8, dy=3),
        "skill_1": dict(hands=[(52, -22), (40, -40)], mouth=1, lean=-8, dy=3),
    }
    return P[name]


# ------------------------------------------------------------------ ZOMBIE GENDUT
GR = (112, 150, 86, 255)
GRAY = (140, 140, 130, 255)


def gendut(pose):
    c = Cv()
    dy = pose.get("dy", 0)

    def T(x, y):
        t = max(0.0, min(1.0, (190 - y) / 140.0))
        return (x, y + dy * (0.6 + 0.4 * t))

    knee = pose.get("knee", 0) + dy * 0.3
    fd = pose.get("foot", [(0, 0), (0, 0)])
    for i, s in enumerate((-1, 1)):
        hip = T(128 + s * 24, 190)
        foot = (128 + s * 24 + fd[i][0], 238 + fd[i][1])
        mid = ((hip[0] + foot[0]) / 2 + s * knee, (hip[1] + foot[1]) / 2)
        c.cap(hip, mid, 30, (78, 68, 58, 255))
        c.cap(mid, foot, 30, (78, 68, 58, 255))
        c.rrect((foot[0], foot[1] + 8), 46, 22, (38, 30, 30, 255), ol=1.5, r=8)
    bc = T(128, 135)
    c.ell(bc, 68, 62, GR)
    # kain perut (dipotong bentuk badan)
    cloth = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(cloth)
    zz = [(50, 128), (206, 128), (206, 200), (178, 182), (166, 196), (154, 182), (142, 198), (128, 184), (114, 198), (102, 182), (90, 196), (78, 182), (50, 200)]
    cd.polygon([(x * SS, (y + bc[1] - 135) * SS) for x, y in zz], fill=GRAY)
    mask = Image.new("L", c.im.size, 0)
    ImageDraw.Draw(mask).ellipse([(bc[0] - 68) * SS, (bc[1] - 62) * SS, (bc[0] + 68) * SS, (bc[1] + 62) * SS], fill=255)
    c.im.paste(cloth, (0, 0), Image.composite(cloth.split()[3], Image.new("L", c.im.size, 0), mask))
    c.line((62, bc[1] - 7), (194, bc[1] - 7), OL, 3.2)
    c.ell((128, bc[1] + 26), 7, 5, GR, ol=2)
    for k in range(3):
        c.line((82 + k * 3, bc[1] + 4 + k * 7), (98 + k * 3, bc[1] + 10 + k * 7), (96, 140, 70, 255), 2)
    hc = T(128, 56)
    c.circle(hc, 25, (112, 150, 86, 255))
    spiky_hair(c, hc[0], hc[1] - 1)
    eyes(c, hc[0], hc[1], 11, 6.4, (240, 215, 60, 255))
    mouth(c, hc[0], hc[1] + 15, pose.get("mouth", 0))
    for i, s in enumerate((-1, 1)):
        S = T(128 + s * 56, 98)
        el, hand, dr = ik(S, pose["hands"][i], 30, 30, s)
        c.cap(S, el, 24, GRAY)
        c.cap(el, hand, 24, GRAY)
        c.circle(hand, 17, GR, ol=2.6)
        for k in (-1, 0, 1):
            c.line((hand[0] + k * 6 - 4, hand[1] - 11), (hand[0] + k * 6 - 4, hand[1] + 2), (70, 100, 56, 255), 1.6)
    return c


def gendut_pose(name):
    P = {
        "idle_0": dict(hands=[(10, 56), (10, 56)]),
        "idle_1": dict(hands=[(16, 56), (16, 56)], dy=2),
        "jump_0": dict(hands=[(14, 54), (14, 54)], dy=16, knee=8, foot=[(-4, 0), (4, 0)]),
        "jump_1": dict(hands=[(38, 6), (38, 6)], dy=-12, knee=12, foot=[(-6, -18), (6, -14)], mouth=1),
        "skill_0": dict(hands=[(-44, -30), (-44, -30)], mouth=1, dy=3),   # kuda-kuda menjaga (perisai)
        "skill_1": dict(hands=[(-38, -26), (-40, -34)], mouth=1, dy=5),
    }
    return P[name]


# ------------------------------------------------------------------ ZOMBIE SUSTER
SKIN = (196, 208, 188, 255)
DRESS = (234, 234, 228, 255)
BLOODC = (150, 20, 28, 255)
HAIR = (62, 44, 46, 255)


def suster(pose):
    c = Cv()
    dy, lean = pose.get("dy", 0), pose.get("lean", 0)

    def T(x, y):
        t = max(0.0, min(1.0, (165 - y) / 125.0))
        return (x + lean * t, y + dy * (0.8 + 0.2 * t))

    knee = pose.get("knee", 0) + dy * 0.4
    fd = pose.get("foot", [(0, 0), (0, 0)])
    for i, s in enumerate((-1, 1)):
        hip = T(128 + s * 13, 160)
        foot = (128 + s * 13 + fd[i][0], 236 + fd[i][1])
        mid = ((hip[0] + foot[0]) / 2 + s * knee, (hip[1] + foot[1]) / 2)
        c.cap(hip, mid, 15, SKIN)
        c.cap(mid, foot, 15, SKIN)
        c.rrect((foot[0], foot[1] + 8), 28, 16, (108, 108, 116, 255), ol=1.5, r=6)
    # rambut panjang di belakang
    hc = T(128, 45)
    c.poly([(hc[0] - 26, hc[1] - 4), (hc[0] + 26, hc[1] - 4), (hc[0] + 34, hc[1] + 52), (hc[0] + 18, hc[1] + 66),
            (hc[0] + 6, hc[1] + 50), (hc[0] - 6, hc[1] + 64), (hc[0] - 18, hc[1] + 50), (hc[0] - 34, hc[1] + 56)], HAIR, ol=2)
    # gaun
    pts = [(100, 72), (156, 72), (160, 112), (176, 168), (166, 164), (158, 172), (148, 164), (138, 172), (128, 164), (118, 172), (108, 164), (98, 172), (90, 164), (80, 168), (96, 112)]
    c.poly([T(*p) for p in pts], DRESS)
    c.line(T(104, 112), T(152, 112), (200, 200, 194, 255), 2)
    # palang merah di dada + noda darah
    c.rrect(T(128, 92), 6, 20, (170, 24, 30, 255), ol=0.8, r=1)
    c.rrect(T(128, 92), 20, 6, (170, 24, 30, 255), ol=0.8, r=1)
    for (x, y, rx, ry) in ((110, 130, 9, 6), (146, 140, 7, 10), (124, 154, 11, 5), (104, 102, 4, 7)):
        p = T(x, y)
        c.d.ellipse([(p[0] - rx) * SS, (p[1] - ry) * SS, (p[0] + rx) * SS, (p[1] + ry) * SS], fill=BLOODC)
    c.line(T(90, 164), T(166, 164), BLOODC, 2)
    # kepala
    c.circle(hc, 23, SKIN)
    # poni + topi suster
    c.poly([(hc[0] - 24, hc[1] - 4), (hc[0] - 14, hc[1] - 14), (hc[0] - 2, hc[1] - 6), (hc[0] + 10, hc[1] - 15), (hc[0] + 24, hc[1] - 4), (hc[0] + 24, hc[1] - 12), (hc[0], hc[1] - 22), (hc[0] - 24, hc[1] - 12)], HAIR, ol=1.2)
    c.poly([(hc[0] - 21, hc[1] - 15), (hc[0] + 21, hc[1] - 15), (hc[0] + 17, hc[1] - 33), (hc[0] - 17, hc[1] - 33)], DRESS, ol=1.8)
    c.rrect((hc[0], hc[1] - 25), 4.5, 15, (170, 24, 30, 255), ol=0.6, r=1)
    c.rrect((hc[0], hc[1] - 25), 15, 4.5, (170, 24, 30, 255), ol=0.6, r=1)
    eyes(c, hc[0], hc[1] + 1, 9, 5.8, (235, 70, 60, 255), pupil=(250, 230, 120, 255))
    mouth(c, hc[0], hc[1] + 13, pose.get("mouth", 0), blood=BLOODC)
    # lengan (lengan baju pendek putih + lengan pucat)
    for i, s in enumerate((-1, 1)):
        S = T(128 + s * 31, 80)
        el, hand, dr = ik(S, pose["hands"][i], 25, 24, s)
        c.cap(el, hand, 12, SKIN)
        c.cap(S, (S[0] + (el[0] - S[0]) * 0.55, S[1] + (el[1] - S[1]) * 0.55), 15, DRESS)
        c.circle(hand, 8.5, SKIN, ol=2)
        claws(c, hand, dr, n=3, size=10, spread=0.55, base=8)
    return c


def suster_pose(name):
    P = {
        "idle_0": dict(hands=[(18, 46), (18, 46)]),
        "idle_1": dict(hands=[(22, 50), (22, 50)], dy=1),
        "walk_0": dict(hands=[(16, 40), (24, 52)], foot=[(0, -9), (0, 0)], lean=-3),
        "walk_1": dict(hands=[(18, 46), (18, 46)]),
        "walk_2": dict(hands=[(24, 52), (16, 40)], foot=[(0, 0), (0, -9)], lean=3),
        "walk_3": dict(hands=[(18, 46), (18, 46)]),
        "shoot_0": dict(hands=[(46, -24), (46, -24)], mouth=1),
        "shoot_1": dict(hands=[(-3, 20), (-3, 20)], mouth=1, lean=6, dy=4),
        "jump_0": dict(hands=[(14, 50), (14, 50)], dy=16, knee=5, foot=[(-3, 0), (3, 0)]),
        "jump_1": dict(hands=[(40, -20), (40, -20)], dy=-10, knee=9, foot=[(-5, -20), (5, -14)], mouth=1),
        "skill_0": dict(hands=[(47, -8), (47, -8)], mouth=1),        # tangan terentang, kabut virus
        "skill_1": dict(hands=[(44, -18), (44, -18)], mouth=1, dy=-2),
    }
    return P[name]


# ------------------------------------------------------------------ efek skill
def render(kind, name):
    pose = {"zombie": zombie_pose, "gendut": gendut_pose, "suster": suster_pose}[kind](name)
    c = {"zombie": zombie, "gendut": gendut, "suster": suster}[kind](pose)
    bg = fg = None
    alpha = 1.0
    if name.startswith("skill"):
        k = int(name[-1])
        if kind == "zombie":      # aura merah + garis kecepatan
            bg = glow((255, 60, 40), (128, 130), 105 + k * 8, 120)
            fg = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(fg)
            for i in range(7):
                y = 70 + i * 24 + k * 9
                x = 14 + (i * 37 + k * 20) % 40
                d.line([(x * SS, y * SS), ((x + 36) * SS, y * SS)], fill=(255, 120, 90, 200), width=3 * SS)
                d.line([((W - x - 36) * SS, (y + 10) * SS), ((W - x) * SS, (y + 10) * SS)], fill=(255, 120, 90, 200), width=3 * SS)
        elif kind == "gendut":    # gelembung perisai biru
            R = 118 + k * 6
            bg = glow((70, 140, 255), (128, 140), R - 6, 70, 10)
            fg = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
            d = ImageDraw.Draw(fg)
            d.ellipse([(128 - R) * SS, (140 - R) * SS, (128 + R) * SS, (140 + R) * SS], outline=(150, 205, 255, 230), width=5 * SS)
            d.arc([(128 - R + 12) * SS, (140 - R + 12) * SS, (128 + R - 12) * SS, (140 + R - 12) * SS], 200, 260, fill=(255, 255, 255, 200), width=5 * SS)
        else:                      # kabut virus hijau, badan setengah tembus
            alpha = 0.6
            bg = glow((90, 230, 120), (128, 150), 112, 150)
            fg = Image.new("RGBA", c.im.size, (0, 0, 0, 0))
            for (x, y, r) in ((70, 205, 34), (190, 200, 38), (128, 232, 44), (96, 150, 26), (170, 120, 28), (110, 80, 22)):
                fg = Image.alpha_composite(fg, glow((120, 255, 150), (x + k * 8, y - k * 6), r, 120, 14))
    return finish(c, bg, fg, alpha)


def tilt(img, deg):
    """rotasi (jatuh) lalu letakkan di dasar kanvas"""
    big = Image.new("RGBA", (W * SS * 2, W * SS * 2), (0, 0, 0, 0))
    big.paste(img, (W * SS // 2, W * SS // 2))
    r = big.rotate(deg, resample=Image.BICUBIC, center=(W * SS, (235 + W // 2) * SS))
    bb = r.getbbox()
    crop = r.crop(bb)
    sc = min(1.0, (W * SS - 8 * SS) / crop.width, (W * SS - 6 * SS) / crop.height)
    if sc < 1.0:
        crop = crop.resize((int(crop.width * sc), int(crop.height * sc)), Image.LANCZOS)
    out = Image.new("RGBA", (W * SS, W * SS), (0, 0, 0, 0))
    out.paste(crop, ((W * SS - crop.width) // 2, W * SS - 4 * SS - crop.height))
    return out


def save_frame(folder, name, im):
    os.makedirs(os.path.join(AS, folder), exist_ok=True)
    im.save(os.path.join(AS, folder, name + ".png"))


def build_char(kind, folder, full):
    names = ["jump_0", "jump_1", "skill_0", "skill_1"]
    if full:
        names = ["idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3", "shoot_0", "shoot_1"] + names
    for n in names:
        save_frame(folder, n, down(render(kind, n)))
    if full:
        base = finish(({"zombie": zombie, "gendut": gendut, "suster": suster}[kind])({"zombie": zombie_pose, "gendut": gendut_pose, "suster": suster_pose}[kind]("idle_0")))
        for i, a in enumerate((22, 52, 80, 92)):
            save_frame(folder, "die_%d" % i, down(tilt(base, a)))
    print("ok", folder)


def build_samurai():
    d = os.path.join(AS, "char_samurai")
    idle = Image.open(os.path.join(d, "idle_0.png")).convert("RGBA")
    walk = Image.open(os.path.join(d, "walk_1.png")).convert("RGBA")
    sh0 = Image.open(os.path.join(d, "shoot_0.png")).convert("RGBA")
    sh1 = Image.open(os.path.join(d, "shoot_1.png")).convert("RGBA")

    def scaled(im, sx, sy, dx=0, dy=0):
        bb = im.getbbox()
        cr = im.crop(bb)
        cr = cr.resize((int(cr.width * sx), int(cr.height * sy)), Image.LANCZOS)
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.paste(cr, ((im.width - cr.width) // 2 + dx, im.height - 2 - cr.height + dy), cr)
        return out

    def aura(im, col, k):
        g = glow(col, (128, 130), 104 + k * 8, 110).resize(im.size, Image.LANCZOS)
        return Image.alpha_composite(g, im)

    scaled(idle, 1.08, 0.86).save(os.path.join(d, "jump_0.png"))                  # jongkok tolak
    scaled(walk, 0.94, 1.08, 0, -20).save(os.path.join(d, "jump_1.png"))          # melayang
    aura(sh0, (120, 200, 255), 0).save(os.path.join(d, "skill_0.png"))            # tebasan berat menyala
    aura(sh1, (150, 220, 255), 1).save(os.path.join(d, "skill_1.png"))
    print("ok char_samurai")


# ------------------------------------------------------------------ potret kartu (gaya layar pilih zombie)
def biohazard(d, cx, cy, r, col):
    for a in (90, 210, 330):
        x = cx + math.cos(math.radians(a)) * r * 0.55
        y = cy - math.sin(math.radians(a)) * r * 0.55
        d.ellipse([x - r * 0.5, y - r * 0.5, x + r * 0.5, y + r * 0.5], outline=col, width=max(2, int(r * 0.16)))
    d.ellipse([cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22], fill=col)
    d.ellipse([cx - r * 1.12, cy - r * 1.12, cx + r * 1.12, cy + r * 1.12], outline=col, width=max(2, int(r * 0.1)))


def portrait(kind, tint):
    c = {"zombie": zombie, "gendut": gendut, "suster": suster}[kind]({"zombie": zombie_pose, "gendut": gendut_pose, "suster": suster_pose}[kind]("skill_0" if kind != "gendut" else "idle_0"))
    img = finish(c)
    # potong bagian kepala + dada
    box = {"zombie": (38, 0, 218, 150), "gendut": (28, 4, 228, 160), "suster": (34, 0, 222, 158)}[kind]
    crop = img.crop(tuple(v * SS for v in box))
    PW, PH = 300, 360
    sc = min(PW / crop.width, PH / crop.height) * 1.0
    crop = crop.resize((int(crop.width * sc), int(crop.height * sc)), Image.LANCZOS)
    bgc = Image.new("RGBA", (PW, PH), (12, 8, 10, 255))
    yy, xx = np.mgrid[0:PH, 0:PW]
    dist = np.sqrt(((xx - PW / 2) / (PW * 0.7)) ** 2 + ((yy - PH * 0.45) / (PH * 0.7)) ** 2)
    arr = np.zeros((PH, PW, 4), dtype=np.uint8)
    f = np.clip(1.0 - dist, 0, 1)
    for ch in range(3):
        arr[..., ch] = (12 + f * tint[ch]).astype(np.uint8)
    arr[..., 3] = 255
    bgc = Image.fromarray(arr, "RGBA")
    bgc.alpha_composite(crop, ((PW - crop.width) // 2, PH - crop.height))
    d = ImageDraw.Draw(bgc)
    biohazard(d, PW - 34, 34, 15, (240, 200, 30, 255))
    # gradasi gelap di bawah untuk teks
    sh = np.zeros((PH, PW, 4), dtype=np.uint8)
    g = np.clip((yy - PH * 0.62) / (PH * 0.38), 0, 1)
    sh[..., 3] = (g * 200).astype(np.uint8)
    bgc.alpha_composite(Image.fromarray(sh, "RGBA"))
    return bgc


# ------------------------------------------------------------------ tangan first-person
def split_hands(im):
    w = im.width // 2
    return im.crop((0, 0, w, im.height)), im.crop((w, 0, im.width, im.height))


def xform(part, angle, dx, dy, sc=1.0):
    p = part
    if sc != 1.0:
        p = p.resize((int(p.width * sc), int(p.height * sc)), Image.LANCZOS)
    p = p.rotate(angle, resample=Image.BICUBIC, expand=True, center=(p.width / 2, p.height))
    out = Image.new("RGBA", part.size, (0, 0, 0, 0))
    out.paste(p, (int((part.width - p.width) / 2 + dx), int(part.height - p.height + dy)), p)
    return out


def tint_img(im, col, amt):
    a = np.array(im).astype(np.float32)
    m = a[..., 3:4] / 255.0
    for ch in range(3):
        a[..., ch] = a[..., ch] * (1 - amt * m[..., 0]) + col[ch] * amt * m[..., 0]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def hand_variants(prefix, src_names, out_prefix, glow_col, skill_mode):
    f0 = Image.open(os.path.join(AS, src_names[0])).convert("RGBA")
    f1 = Image.open(os.path.join(AS, src_names[1])).convert("RGBA")
    # LOMPAT: tangan terangkat & membuka ke samping
    l, r = split_hands(f1)
    jl, jr = xform(l, 14, -18, -46, 1.04), xform(r, -14, 18, -46, 1.04)
    jump = Image.new("RGBA", f1.size, (0, 0, 0, 0))
    jump.paste(jl, (0, 0), jl)
    jump.paste(jr, (jump.width // 2, 0), jr)
    # SKILL
    l, r = split_hands(f0)
    if skill_mode == "claw":      # cakar melebar + aura merah
        sl, sr = xform(l, -10, 10, -22, 1.1), xform(r, 10, -10, -22, 1.1)
    elif skill_mode == "guard":   # kepalan menyatu di depan (perisai)
        sl, sr = xform(l, -16, 70, -40, 1.08), xform(r, 16, -70, -40, 1.08)
    else:                         # tangan terbuka lebar (kabut)
        sl, sr = xform(l, 18, -40, -30, 1.08), xform(r, -18, 40, -30, 1.08)
    sk = Image.new("RGBA", f0.size, (0, 0, 0, 0))
    sk.paste(sl, (0, 0), sl)
    sk.paste(sr, (sk.width // 2, 0), sr)
    g = glow(glow_col, (0, 0), 1, 0)  # placeholder (agar impor glow tidak dianggap tak terpakai)
    del g
    halo = Image.new("RGBA", f0.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([f0.width * 0.12, f0.height * 0.02, f0.width * 0.88, f0.height * 1.0], fill=glow_col[:3] + (90,))
    halo = halo.filter(ImageFilter.GaussianBlur(40))
    sk = Image.alpha_composite(halo, tint_img(sk, glow_col, 0.22))
    jump.save(os.path.join(AS, "%s_2.png" % out_prefix))
    sk.save(os.path.join(AS, "%s_3.png" % out_prefix))


def recolor_suster(im):
    a = np.array(im).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    out = a.copy()
    green = (g > r + 18) & (g > b + 30)
    blue = (b > r + 25) & (b > g + 10)
    claw = (r > 200) & (g > 190) & (b > 160)
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 150.0
    for ch, base in enumerate((200, 210, 192)):
        out[..., ch] = np.where(green, np.clip(base * lum * 1.05, 0, 255), out[..., ch])
    for ch, base in enumerate((236, 236, 230)):
        out[..., ch] = np.where(blue, np.clip(base * (0.55 + (0.3 * r + 0.59 * g + 0.11 * b) / 130.0 * 0.45), 0, 255), out[..., ch])
    for ch, base in enumerate((120, 18, 24)):
        out[..., ch] = np.where(claw, base, out[..., ch])
    # noda darah di lengan baju
    yy, xx = np.mgrid[0:im.height, 0:im.width]
    stain = blue & (((xx // 23 + yy // 31) % 4) == 0)
    for ch, base in enumerate((150, 22, 30)):
        out[..., ch] = np.where(stain, base, out[..., ch])
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def build_hands():
    hand_variants("zombie", ("zombie_hands_0.png", "zombie_hands_1.png"), "zombie_hands", (255, 70, 50, 255), "claw")
    hand_variants("gendut", ("gendut_fists_0.png", "gendut_fists_1.png"), "gendut_fists", (80, 150, 255, 255), "guard")
    for i in range(4):
        z = Image.open(os.path.join(AS, "zombie_hands_%d.png" % i)).convert("RGBA")
        recolor_suster(z).save(os.path.join(AS, "suster_hands_%d.png" % i))
    # suster: skill = tangan terbuka lebar + halo hijau
    f0 = recolor_suster(Image.open(os.path.join(AS, "zombie_hands_0.png")).convert("RGBA"))
    l, r = split_hands(f0)
    sl, sr = xform(l, 18, -40, -30, 1.08), xform(r, -18, 40, -30, 1.08)
    sk = Image.new("RGBA", f0.size, (0, 0, 0, 0))
    sk.paste(sl, (0, 0), sl)
    sk.paste(sr, (sk.width // 2, 0), sr)
    halo = Image.new("RGBA", f0.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([f0.width * 0.1, 0, f0.width * 0.9, f0.height], fill=(90, 230, 120, 100))
    sk = Image.alpha_composite(halo.filter(ImageFilter.GaussianBlur(40)), tint_img(sk, (110, 255, 140, 255), 0.2))
    sk.save(os.path.join(AS, "suster_hands_3.png"))
    print("ok hands")


if __name__ == "__main__":
    build_char("zombie", "char_zombie", False)
    build_char("gendut", "char_gendut", False)
    build_char("suster", "char_suster", True)
    build_samurai()
    for kind, name, tint in (("zombie", "biasa", (150, 40, 30)), ("gendut", "gendut", (40, 110, 150)), ("suster", "suster", (40, 140, 60))):
        portrait(kind, tint).save(os.path.join(AS, "portrait_%s.png" % name))
    build_hands()
