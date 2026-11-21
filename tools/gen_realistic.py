#!/usr/bin/env python3
"""Generator karakter REALISTIS Crisis Action DTP v0.0.3.2 (gambar dibuat dengan kode, tanpa aset luar).
Jalankan:  python3 tools/gen_realistic.py   (butuh pillow + numpy)

Nama file & jumlah frame SAMA dengan versi lama, jadi animasi di bot.gd / player.gd tidak berubah.
Yang diganti hanya gambarnya: pencahayaan berbayang, tekstur kulit/kain, proporsi tubuh nyata, luka & darah.

Hasil:
  assets/char_blue|char_red      tentara tim biru / merah (idle, walk, shoot, die)
  assets/char_hero               HERO manusia (rambut merah, jaket taktis)
  assets/char_civil|civil2|civil3  ORANG BIASA (3 variasi)
  assets/char_zombie|gendut|suster  zombie (lengkap: idle, walk, shoot, die, jump, skill)
  assets/char_samurai            samurai (lengkap)
  assets/zombie_hands_0..3, gendut_fists_0..3, suster_hands_0..3   tangan first-person
  assets/portrait_*.png          kartu pilih zombie (+ induk, hero, civil)
  assets/face_*.png              foto kecil untuk HUD (gaya Crisis Action)
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
AS = os.path.join(HERE, "..", "assets")
SS = 3
W = 256
N = W * SS
RNG = np.random.RandomState(11)


def S(p):
    return (p[0] * SS, p[1] * SS)


def noise(h, w, scale):
    n = RNG.rand(h // scale + 2, w // scale + 2).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0 - 0.5


# ------------------------------------------------------------------ pembuat bentuk
def f_limb(a, b, w1, w2=None):
    w2 = w1 if w2 is None else w2

    def f(d):
        ang = math.atan2(b[1] - a[1], b[0] - a[0]) + math.pi / 2
        ox, oy = math.cos(ang), math.sin(ang)
        d.polygon([S((a[0] + ox * w1 / 2, a[1] + oy * w1 / 2)), S((b[0] + ox * w2 / 2, b[1] + oy * w2 / 2)),
                   S((b[0] - ox * w2 / 2, b[1] - oy * w2 / 2)), S((a[0] - ox * w1 / 2, a[1] - oy * w1 / 2))], fill=255)
        for p, w in ((a, w1), (b, w2)):
            x, y = S(p)
            r = w * SS / 2
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return f


def f_ell(c, rx, ry):
    def f(d):
        x, y = S(c)
        d.ellipse([x - rx * SS, y - ry * SS, x + rx * SS, y + ry * SS], fill=255)
    return f


def f_poly(pts):
    def f(d):
        d.polygon([S(p) for p in pts], fill=255)
    return f


def f_rect(c, w, h, r=2):
    def f(d):
        x, y = S(c)
        d.rounded_rectangle([x - w * SS / 2, y - h * SS / 2, x + w * SS / 2, y + h * SS / 2], radius=r * SS, fill=255)
    return f


def f_multi(*fs):
    def f(d):
        for g in fs:
            g(d)
    return f


class Cv:
    def __init__(s, w=N, h=N):
        s.w, s.h = w, h
        s.P = np.zeros((h, w, 3), np.float32)   # warna x alpha
        s.A = np.zeros((h, w), np.float32)
        s.n1 = noise(h, w, 14)
        s.n2 = noise(h, w, 3)

    def mask(s, fn):
        m = Image.new("L", (s.w, s.h), 0)
        fn(ImageDraw.Draw(m))
        return m

    def part(s, fn, col, r=5.0, light=0.6, tex=0.10, edge=0.55, clip=None):
        m = s.mask(fn)
        a = np.asarray(m, np.float32) / 255.0
        if a.max() == 0:
            return a
        b = np.asarray(m.filter(ImageFilter.GaussianBlur(r * SS)), np.float32) / 255.0
        gy, gx = np.gradient(b)
        lit = -(gx * -0.6 + gy * -0.75)
        lit /= (np.abs(lit).max() + 1e-6)
        sh = 1.0 + light * lit * 1.25
        e = np.clip((b - 0.42) / 0.4, 0, 1)
        occ = (1.0 - edge) + edge * e
        t = 1.0 + tex * (s.n1 * 1.7 + s.n2)
        rgb = np.array(col[:3], np.float32)[None, None, :] * (sh * occ * t)[..., None]
        if clip is not None:
            a = a * clip
        s.P = s.P * (1 - a[..., None]) + rgb * a[..., None]
        s.A = a + s.A * (1 - a)
        return a

    def image(s):
        A = np.maximum(s.A, 1e-5)
        rgb = np.clip(s.P / A[..., None], 0, 255)
        out = np.dstack([rgb, np.clip(s.A, 0, 1) * 255]).astype(np.uint8)
        return Image.fromarray(out, "RGBA")


def decal_simple(cv, fn, col, alpha=0.6, blur=1.0):
    """cat/bercak di atas tubuh: hanya di dalam siluet (P = warna x alpha)"""
    m = cv.mask(fn)
    if blur > 0:
        m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    a = np.asarray(m, np.float32) / 255.0 * alpha * (cv.A > 0.02)
    cv.P = cv.P * (1 - a[..., None]) + np.array(col[:3], np.float32)[None, None, :] * (a * cv.A)[..., None]


def blotches(cv, n, box, size, col, alpha, seed, blur=1.2):
    r = np.random.RandomState(seed)
    items = [(r.uniform(box[0], box[2]), r.uniform(box[1], box[3]), r.uniform(size[0], size[1]), r.uniform(size[0], size[1]) * 0.7) for _ in range(n)]

    def f(d):
        for x, y, rx, ry in items:
            X, Y = S((x, y))
            d.ellipse([X - rx * SS, Y - ry * SS, X + rx * SS, Y + ry * SS], fill=255)
    decal_simple(cv, f, col, alpha, blur)


def line_decal(cv, pts, col, w, alpha=0.8, blur=0.4):
    def f(d):
        d.line([S(p) for p in pts], fill=255, width=max(1, int(w * SS)), joint="curve")
    decal_simple(cv, f, col, alpha, blur)


# ------------------------------------------------------------------ rangka
def ik(Sh, tgt, l1, l2, side):
    tx, ty = side * tgt[0], tgt[1]
    d = max(math.hypot(tx, ty), 1e-3)
    d = min(d, l1 + l2 - 0.5)
    ux, uy = tx / math.hypot(tx, ty + 1e-9), ty / math.hypot(tx, ty + 1e-9)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    best = None
    for sg in (1, -1):
        ex = Sh[0] + ux * a + (-uy) * h * sg
        ey = Sh[1] + uy * a + ux * h * sg
        score = side * (ex - Sh[0]) + 0.6 * (ey - Sh[1])
        if best is None or score > best[0]:
            best = (score, (ex, ey))
    hand = (Sh[0] + ux * d, Sh[1] + uy * d)
    return best[1], hand, (ux, uy)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


# warna kulit
SKIN_A = (205, 158, 120)
SKIN_B = (178, 128, 92)
SKIN_C = (226, 184, 152)
ZSKIN = (128, 150, 112)      # pucat kehijauan
ZSKIN_D = (104, 122, 92)
BLOOD = (120, 12, 16)
BLOOD2 = (170, 22, 24)


def T_factory(pose, ytop=130.0, yspan=110.0, lean_w=1.0):
    dy, lean = pose.get("dy", 0), pose.get("lean", 0)

    def T(x, y):
        t = max(0.0, min(1.0, (ytop - y) / yspan))
        return (x + lean * t * lean_w, y + dy * (0.8 + 0.2 * t))
    return T


# ------------------------------------------------------------------ kepala
def head(cv, c, rx, ry, skin, dead=False, mouth=0, eye=(60, 40, 30), glow=None, mask=False):
    cx, cy = c
    cv.part(f_limb((cx, cy + ry * 0.7), (cx, cy + ry + 10), rx * 0.62), shade(skin, 0.86), r=3, edge=0.3)   # leher
    cv.part(f_ell(c, rx, ry), skin, r=5, light=0.7, tex=0.06)
    for s in (-1, 1):       # telinga
        cv.part(f_ell((cx + s * (rx + 0.5), cy + 1), 2.6, 4.2), shade(skin, 0.92), r=1, edge=0.4)
    ey = cy - ry * 0.05
    sp = rx * 0.46
    # rongga mata & bayangan
    for s in (-1, 1):
        decal_simple(cv, f_ell((cx + s * sp, ey), 5.8, 4.2), (40, 25, 22) if not dead else (24, 14, 14), 0.38 if not dead else 0.75, 1.4)
    for s in (-1, 1):
        ex = cx + s * sp
        if glow is None:
            decal_simple(cv, f_ell((ex, ey), 3.9, 2.4), (236, 232, 224), 0.95, 0.35)
            decal_simple(cv, f_ell((ex, ey), 1.9, 1.9), eye, 1.0, 0.25)
            decal_simple(cv, f_ell((ex, ey), 0.9, 0.9), (10, 8, 8), 1.0, 0.15)
            decal_simple(cv, f_ell((ex - 0.7, ey - 0.7), 0.6, 0.6), (255, 255, 255), 0.9, 0.1)
        else:
            decal_simple(cv, f_ell((ex, ey), 3.6, 2.8), glow, 0.95, 0.5)
            decal_simple(cv, f_ell((ex, ey), 1.2, 2.2), (20, 10, 6), 1.0, 0.2)
        line_decal(cv, [(ex - 4.4, ey - 3.4 - (1.5 if s == -1 and dead else 0)), (ex + 4.4, ey - 3.8 + (1.5 if s == -1 and dead else 0))], (36, 26, 22), 1.5, 0.8)   # alis
    # hidung
    decal_simple(cv, f_poly([(cx - 1.4, ey + 2), (cx + 1.4, ey + 2), (cx + 3.2, ey + 9), (cx - 3.2, ey + 9)]), shade(skin, 0.7), 0.55, 1.1)
    decal_simple(cv, f_ell((cx - 3, ey + 9.4), 1.1, 0.8), (50, 28, 24), 0.7, 0.3)
    decal_simple(cv, f_ell((cx + 3, ey + 9.4), 1.1, 0.8), (50, 28, 24), 0.7, 0.3)
    # mulut
    my = cy + ry * 0.62
    if mouth > 0.5 or dead and mouth > 0.2:
        decal_simple(cv, f_ell((cx, my + 1), 6.2, 4.4), (46, 8, 10), 1.0, 0.5)
        decal_simple(cv, f_rect((cx, my - 1.4), 9, 1.8, 0.5), (222, 214, 190), 0.95, 0.3)
        decal_simple(cv, f_rect((cx, my + 3.2), 7, 1.4, 0.5), (210, 200, 176), 0.8, 0.3)
    else:
        line_decal(cv, [(cx - 5, my), (cx, my + 0.8), (cx + 5, my)], (92, 40, 38) if not dead else (60, 22, 22), 1.4, 0.9, 0.35)
        decal_simple(cv, f_ell((cx, my + 2.5), 4, 1.2), shade(skin, 0.8), 0.3, 0.8)
    # bayangan bawah dagu + highlight pipi
    decal_simple(cv, f_ell((cx, cy + ry * 0.95), rx * 0.9, 3), (0, 0, 0), 0.25, 1.5)
    decal_simple(cv, f_ell((cx - rx * 0.4, cy + 2), 4, 5), (255, 235, 210), 0.10, 2.0)


def zombie_face_damage(cv, c, rx, ry, seed=3):
    cx, cy = c
    blotches(cv, 7, (cx - rx, cy - ry * 0.4, cx + rx, cy + ry), (1.2, 3.4), (90, 80, 60), 0.35, seed, 1.0)
    blotches(cv, 3, (cx - rx * 0.8, cy - ry * 0.2, cx + rx * 0.8, cy + ry * 0.8), (1.0, 2.6), BLOOD, 0.85, seed + 1, 0.6)
    line_decal(cv, [(cx - rx * 0.7, cy - ry * 0.3), (cx - rx * 0.3, cy + ry * 0.1)], BLOOD, 1.2, 0.8)
    for k in range(4):   # pembuluh darah
        x0 = cx - rx * 0.6 + k * 4
        line_decal(cv, [(x0, cy - ry * 0.8), (x0 + 2, cy - ry * 0.4), (x0 + 1, cy - ry * 0.1)], (96, 70, 96), 0.6, 0.45)
    line_decal(cv, [(cx - 5, cy + ry * 0.6), (cx - 7, cy + ry * 1.15)], BLOOD2, 1.5, 0.9, 0.5)   # darah di mulut


# ------------------------------------------------------------------ tubuh manusia umum
def legs(cv, T, pose, pants, shoe, ragged=False, skin=None, hipy=126, w=(21, 16, 11), base=230, sep=11):
    knee = pose.get("knee", 0) + pose.get("dy", 0) * 0.45
    fd = pose.get("foot", [(0, 0), (0, 0)])
    for i, s in enumerate((-1, 1)):
        hip = T(128 + s * sep, hipy)
        foot = (128 + s * sep + fd[i][0], base + fd[i][1])
        mid = ((hip[0] + foot[0]) / 2 + s * knee, (hip[1] + foot[1]) / 2 + 2)
        cv.part(f_limb(hip, mid, w[0], w[1]), pants, r=5, light=0.55)
        cv.part(f_limb(mid, foot, w[1], w[2]), pants, r=4, light=0.55)
        cv.part(f_ell(mid, w[1] / 2 + 1.2, w[1] / 2 + 1.2), shade(pants, 0.92), r=2, edge=0.3)
        line_decal(cv, [(mid[0] - 6, mid[1] - 7), (mid[0] + 1, mid[1] - 2)], shade(pants, 0.55), 1.0, 0.6)
        line_decal(cv, [(mid[0] + 6, mid[1] + 6), (mid[0] - 1, mid[1] + 11)], shade(pants, 0.55), 1.0, 0.6)
        if ragged and skin is not None:
            cv.part(f_limb((mid[0], mid[1] + 8), (foot[0], foot[1] - 6), w[2] - 1), skin, r=2.5, edge=0.4)
        sh = [(foot[0] - s * 6, foot[1] - 3), (foot[0] + s * 6, foot[1] - 3), (foot[0] + s * 8.5, foot[1] + 11), (foot[0] - s * 7, foot[1] + 12)]
        cv.part(f_poly(sh), shoe, r=3, light=0.7)
        line_decal(cv, [(foot[0] - 8, foot[1] + 11), (foot[0] + 8, foot[1] + 11)], (14, 12, 12), 2.0, 0.9)


def arms(cv, T, pose, sleeve, skin, glove=None, sleeve_len=0.55, l=(34, 32), wid=(15, 11), sy=62, sx=29, claws=0, hands_abs=None):
    out = []
    for i, s in enumerate((-1, 1)):
        Sh = T(128 + s * sx, sy)
        if hands_abs is not None:
            ta = hands_abs[i]
            tgt = (s * (ta[0] - Sh[0]), ta[1] - Sh[1])
        else:
            tgt = pose["hands"][i]
        el, hand, dr = ik(Sh, tgt, l[0], l[1], s)
        out.append((Sh, el, hand, dr))
        cv.part(f_limb(Sh, el, wid[0], wid[0] - 2), sleeve, r=4, light=0.6)
        fore_col = sleeve if sleeve_len >= 0.99 else skin
        cv.part(f_limb(el, hand, wid[1] + 1.5 if fore_col == sleeve else wid[1], wid[1] - 1.5), fore_col, r=3, light=0.6)
        line_decal(cv, [(el[0] - 4, el[1] - 2), (el[0] + 4, el[1] + 3)], shade(sleeve, 0.55), 1.0, 0.6)
        hc = glove if glove is not None else skin
        cv.part(f_ell(hand, 6.4, 6.8), hc, r=2.2, light=0.7, edge=0.5)
        if claws:
            ang = math.atan2(dr[1], dr[0])
            for k in range(claws):
                a = ang + (k - (claws - 1) / 2) * 0.5
                bx, by = hand[0] + math.cos(a) * 5, hand[1] + math.sin(a) * 5
                tx, ty = hand[0] + math.cos(a) * (5 + 11), hand[1] + math.sin(a) * (5 + 11)
                px, py = -math.sin(a) * 1.7, math.cos(a) * 1.7
                cv.part(f_poly([(bx + px, by + py), (tx, ty), (bx - px, by - py)]), (214, 204, 176), r=0.8, edge=0.5, light=0.6)
    return out


def torso_poly(T, top=56, bot=126, sh=28, wa=21, hip=23):
    return [T(128 - sh, top), T(128 + sh, top), T(128 + sh + 1, top + 14), T(128 + wa, top + 44), T(128 + hip, bot), T(128 - hip, bot), T(128 - wa, top + 44), T(128 - sh - 1, top + 14)]


def rifle(cv, a=(104, 104), b=(196, 82), tone=(36, 38, 42)):
    """senapan: laras panjang diagonal"""
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux

    def pt(t, o):
        return (a[0] + ux * L * t + px * o, a[1] + uy * L * t + py * o)
    cv.part(f_poly([pt(0, -3.5), pt(0.12, -4.5), pt(0.2, -4.5), pt(0.2, 4), pt(0.1, 6), pt(0, 3.5)]), (70, 52, 38), r=1.5, light=0.7)   # popor
    cv.part(f_poly([pt(0.18, -5.5), pt(0.7, -5.5), pt(0.7, 3.5), pt(0.18, 4.5)]), tone, r=1.8, light=0.7)   # body
    cv.part(f_poly([pt(0.55, -3), pt(0.82, -2.6), pt(0.82, 2.6), pt(0.55, 3.2)]), shade(tone, 1.25), r=1.2)   # handguard
    cv.part(f_limb(pt(0.8, 0), pt(1.0, 0), 2.6), shade(tone, 0.8), r=0.8)   # laras
    cv.part(f_poly([pt(0.38, 3), pt(0.5, 3), pt(0.48, 12), pt(0.36, 12)]), shade(tone, 0.8), r=1)   # magasin
    cv.part(f_rect(pt(0.45, -7.4), 15, 3.4, 1), shade(tone, 1.4), r=0.8)   # sight
    return pt(1.0, 0)


def pistol(cv, a=(142, 98), b=(176, 86), tone=(34, 36, 40)):
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    pt = lambda t, o: (a[0] + ux * L * t + px * o, a[1] + uy * L * t + py * o)
    cv.part(f_poly([pt(0.1, -3), pt(1.0, -3), pt(1.0, 1.2), pt(0.1, 1.5)]), tone, r=1.3, light=0.7)
    cv.part(f_poly([pt(0.1, 1), pt(0.38, 1), pt(0.3, 9), pt(0.05, 9)]), shade(tone, 0.85), r=1)
    return pt(1.0, -1)


def muzzle_flash(cv, p, size=26):
    def f(d):
        pts = []
        for k in range(16):
            r = size if k % 2 == 0 else size * 0.42
            a = k * math.pi / 8 + 0.2
            pts.append(S((p[0] + math.cos(a) * r, p[1] + math.sin(a) * r)))
        d.polygon(pts, fill=255)
    m = cv.mask(f)
    a = np.asarray(m.filter(ImageFilter.GaussianBlur(1.2 * SS)), np.float32) / 255.0
    cv.P = cv.P * (1 - a[..., None]) + np.array((255, 214, 110), np.float32)[None, None, :] * a[..., None]
    cv.A = a + cv.A * (1 - a)
    m2 = cv.mask(f_ell(p, size * 0.38, size * 0.38))
    a2 = np.asarray(m2.filter(ImageFilter.GaussianBlur(1.0 * SS)), np.float32) / 255.0
    cv.P = cv.P * (1 - a2[..., None]) + np.array((255, 252, 230), np.float32)[None, None, :] * a2[..., None]
    cv.A = a2 + cv.A * (1 - a2)


# ------------------------------------------------------------------ poses
def gun_pose(name):
    base = dict(dy=0)
    P = {
        "idle_0": dict(),
        "idle_1": dict(dy=1),
        "walk_0": dict(foot=[(0, -9), (0, 0)], dy=1),
        "walk_1": dict(),
        "walk_2": dict(foot=[(0, 0), (0, -9)], dy=1),
        "walk_3": dict(),
        "shoot_0": dict(flash=True),
        "shoot_1": dict(flash=True, lean=-3, dy=1),
    }
    base.update(P[name])
    return base


def human_body(cv, pose, st, weapon="rifle"):
    """st: dict gaya (warna, helm, rompi, dll)"""
    T = T_factory(pose)
    legs(cv, T, pose, st["pants"], st["shoe"], sep=11)
    # kantong paha / lutut
    if st.get("cargo"):
        for s in (-1, 1):
            p = T(128 + s * 17, 150)
            cv.part(f_rect(p, 10, 12, 1.5), shade(st["pants"], 1.12), r=1.2, edge=0.45)
    # torso
    tp = torso_poly(T)
    tors = cv.part(f_poly(tp), st["shirt"], r=7, light=0.6)
    if st.get("camo"):
        blotches(cv, 14, (98, 62, 158, 124), (4, 9), shade(st["shirt"], 0.7), 0.5, 5, 1.6)
        blotches(cv, 10, (98, 62, 158, 124), (3, 7), shade(st["shirt"], 1.25), 0.4, 9, 1.6)
    # lipatan kain
    line_decal(cv, [T(104, 100), T(118, 108), T(124, 122)], shade(st["shirt"], 0.5), 1.4, 0.45, 0.6)
    line_decal(cv, [T(152, 98), T(140, 108), T(134, 122)], shade(st["shirt"], 0.5), 1.4, 0.45, 0.6)
    # kepala di belakang rompi/kerah dulu
    hc = T(128, 28)
    # ikat pinggang
    cv.part(f_poly([T(105, 118), T(151, 118), T(152, 127), T(104, 127)]), st.get("belt", (36, 30, 26)), r=1.5, edge=0.5)
    cv.part(f_rect(T(128, 122.5), 7, 6, 1), (176, 158, 90), r=1, edge=0.4)
    if st.get("vest"):
        v = st["vest"]
        cv.part(f_poly([T(104, 58), T(116, 58), T(120, 70), T(128, 66), T(136, 70), T(140, 58), T(152, 58), T(154, 112), T(102, 112)]), v, r=4, light=0.6)
        for x in (110, 128, 146):
            cv.part(f_rect(T(x, 96), 12, 14, 1.5), shade(v, 1.22), r=1.3, edge=0.5)
            line_decal(cv, [T(x - 5, 92), T(x + 5, 92)], shade(v, 0.5), 0.9, 0.7)
        line_decal(cv, [T(104, 74), T(152, 74)], shade(v, 0.55), 1.0, 0.5)
    for k in range(2):   # tali bahu
        pass
    # tangan & senjata
    pose_hands = None
    if weapon == "rifle":
        grip, fore = (138, 98), (163, 92)
        pose_hands = [grip, fore]
    elif weapon == "pistol":
        pose_hands = [(144, 100), (150, 96)]
    sl = st.get("sleeve", st["shirt"])
    a = arms(cv, T, pose, sl, st["skin"], glove=st.get("glove"), sleeve_len=st.get("sleeve_len", 1.0), hands_abs=pose_hands)
    return T, hc


def gun_draw_front(cv, pose, weapon, flash):
    if weapon == "rifle":
        tip = rifle(cv, (104, 104 + pose.get("dy", 0)), (198, 84 + pose.get("dy", 0)))
    else:
        tip = pistol(cv, (142, 100 + pose.get("dy", 0)), (178, 90 + pose.get("dy", 0)))
    if flash:
        muzzle_flash(cv, (tip[0] + 6, tip[1] - 1), 24 if weapon == "rifle" else 18)


def hair_short(cv, hc, col, style="short", ry=15):
    cx, cy = hc
    if style == "short":
        cv.part(f_poly([(cx - 13, cy - 2), (cx - 12.5, cy - 10), (cx - 6, cy - ry - 2), (cx + 6, cy - ry - 2), (cx + 12.5, cy - 10), (cx + 13, cy - 2),
                        (cx + 10, cy - 7), (cx + 3, cy - 10), (cx - 6, cy - 9), (cx - 10, cy - 6)]), col, r=2.5, tex=0.2)
    elif style == "spiky":   # hero rambut merah
        cv.part(f_poly([(cx - 14, cy), (cx - 15, cy - 11), (cx - 9, cy - 14), (cx - 7, cy - 22), (cx - 2, cy - 15), (cx + 2, cy - 24), (cx + 6, cy - 15),
                        (cx + 11, cy - 20), (cx + 12, cy - 11), (cx + 15, cy - 9), (cx + 14, cy), (cx + 11, cy - 7), (cx + 4, cy - 11), (cx - 5, cy - 11), (cx - 11, cy - 6)]), col, r=2.2, tex=0.25)
    elif style == "ponytail":
        cv.part(f_poly([(cx - 14, cy + 6), (cx - 14.5, cy - 8), (cx - 7, cy - ry - 3), (cx + 7, cy - ry - 3), (cx + 14.5, cy - 8), (cx + 14, cy + 6),
                        (cx + 10, cy - 6), (cx, cy - 9), (cx - 10, cy - 6)]), col, r=2.5, tex=0.2)
        cv.part(f_limb((cx + 13, cy - 4), (cx + 22, cy + 22), 8, 5), col, r=2, tex=0.2)
    elif style == "bald":
        cv.part(f_poly([(cx - 12, cy - 8), (cx - 6, cy - ry - 1), (cx + 6, cy - ry - 1), (cx + 12, cy - 8), (cx + 7, cy - 9), (cx - 7, cy - 9)]), col, r=2, tex=0.25)
    for k in range(10):
        x = cx - 9 + k * 2
        line_decal(cv, [(x, cy - ry), (x + 1.5, cy - 9)], shade(col, 1.45), 0.5, 0.35, 0.2)


def finish_figure(cv, T, hc, st, pose, weapon, head_kwargs=None):
    hk = dict(skin=st["skin"], eye=st.get("eye", (58, 38, 28)))
    hk.update(head_kwargs or {})
    head(cv, hc, 12.5, 15, **hk)


# ------------------------------------------------------------------ TENTARA (tim biru / merah)
def soldier(pose, team):
    cv = Cv()
    uni = (58, 84, 124) if team == "blue" else (122, 42, 42)
    st = dict(shirt=uni, pants=shade(uni, 0.72), shoe=(24, 22, 22), skin=(60, 52, 48), vest=(46, 50, 54), camo=True, glove=(26, 26, 28),
              cargo=True, belt=(30, 28, 26))
    T, hc = human_body(cv, pose, st, "rifle")
    # kepala: balaclava + helm + kacamata
    head(cv, hc, 12.5, 15, skin=(190, 142, 108), eye=(50, 36, 28))
    cx, cy = hc
    cv.part(f_poly([(cx - 12.6, cy + 1), (cx + 12.6, cy + 1), (cx + 11.5, cy + 15), (cx, cy + 18), (cx - 11.5, cy + 15)]), (30, 30, 32), r=3, tex=0.2)   # masker bawah
    cv.part(f_poly([(cx - 14, cy - 3), (cx - 13, cy - 12), (cx - 6, cy - 19), (cx + 6, cy - 19), (cx + 13, cy - 12), (cx + 14, cy - 3), (cx + 13, cy - 1), (cx - 13, cy - 1)]),
            shade(uni, 0.62), r=3.5, tex=0.18)   # helm
    cv.part(f_rect((cx, cy - 2), 29, 3.5, 1), (30, 30, 32), r=1, edge=0.4)
    cv.part(f_rect((cx, cy - 13), 12, 4, 1.5), shade(uni, 1.5), r=1.2, edge=0.5)   # lencana tim
    cv.part(f_rect((cx, cy + 1.2), 25, 7.4, 2.6), (24, 28, 30), r=1.8, light=0.7)   # kacamata
    for s in (-1, 1):
        decal_simple(cv, f_ell((cx + s * 6.2, cy + 1.2), 4.8, 2.9), (92, 160, 200) if team == "blue" else (210, 150, 90), 0.9, 0.5)
        decal_simple(cv, f_ell((cx + s * 6.2 - 1.5, cy + 0.2), 1.6, 0.8), (255, 255, 255), 0.6, 0.3)
    gun_draw_front(cv, pose, "rifle", pose.get("flash", False))
    # tangan di atas senapan
    T2 = T
    return cv


# ------------------------------------------------------------------ HERO
def hero(pose):
    cv = Cv()
    st = dict(shirt=(40, 42, 46), pants=(58, 62, 66), shoe=(34, 28, 24), skin=SKIN_C, vest=(56, 60, 52), cargo=True, glove=(28, 28, 30), belt=(86, 60, 36),
              sleeve=(36, 38, 42), sleeve_len=1.0)
    T, hc = human_body(cv, pose, st, "rifle")
    # kerah jaket + syal
    cv.part(f_poly([T(112, 56), T(144, 56), T(138, 66), T(128, 70), T(118, 66)]), (30, 32, 34), r=2, edge=0.5)
    head(cv, hc, 12.5, 15, skin=SKIN_C, eye=(70, 44, 30))
    hair_short(cv, hc, (150, 46, 30), "spiky")
    # ban lengan emas + bekas luka kecil
    cv.part(f_rect(T(99, 80), 13, 5, 1), (206, 168, 62), r=1, edge=0.45)
    line_decal(cv, [(hc[0] + 4, hc[1] - 1), (hc[0] + 8, hc[1] + 5)], (150, 70, 60), 0.9, 0.55)
    gun_draw_front(cv, pose, "rifle", pose.get("flash", False))
    return cv


# ------------------------------------------------------------------ ORANG BIASA
CIVIL = {
    "civil": dict(shirt=(70, 110, 150), pants=(52, 66, 96), shoe=(220, 220, 216), skin=SKIN_A, hair=(26, 20, 18), hair_style="short", sleeve_len=0.5),
    "civil2": dict(shirt=(190, 70, 80), pants=(44, 44, 52), shoe=(240, 240, 240), skin=SKIN_C, hair=(34, 22, 20), hair_style="ponytail", sleeve_len=0.5),
    "civil3": dict(shirt=(200, 150, 64), pants=(110, 98, 76), shoe=(70, 52, 40), skin=SKIN_B, hair=(70, 70, 72), hair_style="short", sleeve_len=1.0),
}


def civil(pose, variant):
    cv = Cv()
    cfg = CIVIL[variant]
    st = dict(shirt=cfg["shirt"], pants=cfg["pants"], shoe=cfg["shoe"], skin=cfg["skin"], belt=(40, 32, 26), glove=None, sleeve_len=cfg["sleeve_len"])
    T, hc = human_body(cv, pose, st, "pistol")
    cv.part(f_poly([T(114, 56), T(142, 56), T(136, 64), T(128, 68), T(120, 64)]), shade(cfg["shirt"], 0.85), r=1.5, edge=0.5)   # kerah
    head(cv, hc, 12.5, 15, skin=cfg["skin"], eye=(56, 36, 26))
    hair_short(cv, hc, cfg["hair"], cfg["hair_style"])
    if variant == "civil3":
        line_decal(cv, [(hc[0] - 6, hc[1] + 9), (hc[0], hc[1] + 12), (hc[0] + 6, hc[1] + 9)], (160, 160, 160), 2.4, 0.5, 0.8)   # jenggot
    gun_draw_front(cv, pose, "pistol", pose.get("flash", False))
    return cv


# ------------------------------------------------------------------ ZOMBIE BIASA
def zombie_pose(name):
    P = {
        "idle_0": dict(hands=[(22, 62), (22, 62)]),
        "idle_1": dict(hands=[(26, 66), (26, 66)], dy=1),
        "walk_0": dict(hands=[(22, 56), (30, 74)], foot=[(0, -9), (0, 0)], lean=-3),
        "walk_1": dict(hands=[(26, 64), (26, 64)]),
        "walk_2": dict(hands=[(30, 74), (22, 56)], foot=[(0, 0), (0, -9)], lean=3),
        "walk_3": dict(hands=[(26, 64), (26, 64)]),
        "shoot_0": dict(hands=[(52, -34), (52, -34)], mouth=1),
        "shoot_1": dict(hands=[(-4, 34), (-4, 34)], mouth=1, lean=6, dy=4),
        "jump_0": dict(hands=[(20, 70), (20, 70)], dy=18, knee=6, foot=[(-3, 0), (3, 0)]),
        "jump_1": dict(hands=[(46, -30), (46, -30)], dy=-10, knee=10, foot=[(-6, -22), (6, -16)], mouth=1),
        "skill_0": dict(hands=[(50, -40), (50, -40)], mouth=1, lean=8, dy=3),
        "skill_1": dict(hands=[(56, -26), (42, -46)], mouth=1, lean=-8, dy=3),
    }
    return P[name]


def zombie(pose):
    cv = Cv()
    T = T_factory(pose)
    pants = (64, 58, 52)
    legs(cv, T, pose, pants, (30, 26, 24), ragged=True, skin=ZSKIN_D)
    cloth = (64, 86, 112)
    tp = torso_poly(T)
    cv.part(f_poly(tp), cloth, r=7, light=0.6)
    # kain compang-camping + kulit terbuka + luka
    cv.part(f_poly([T(102, 92), T(112, 100), T(118, 94), T(126, 104), T(134, 96), T(142, 104), T(152, 94), T(150, 124), T(104, 124)]), shade(cloth, 0.7), r=3, edge=0.4)
    blotches(cv, 9, (100, 70, 156, 124), (3, 8), (36, 24, 22), 0.45, 21, 1.4)
    cv.part(f_poly([T(118, 78), T(138, 84), T(134, 108), T(120, 104)]), (150, 96, 90), r=3, edge=0.55)   # kulit terbuka
    cv.part(f_poly([T(122, 84), T(134, 88), T(131, 102), T(123, 99)]), BLOOD, r=2, edge=0.6)
    for k in range(5):
        line_decal(cv, [T(120, 84 + k * 4), T(136, 88 + k * 4)], (214, 200, 176), 1.0, 0.65, 0.3)   # tulang rusuk
    blotches(cv, 6, (100, 62, 156, 124), (3, 7), BLOOD, 0.7, 4, 1.3)
    cv.part(f_poly([T(105, 119), T(151, 119), T(152, 127), T(104, 127)]), (40, 32, 28), r=1.5, edge=0.5)
    arms(cv, T, pose, cloth, ZSKIN, sleeve_len=0.5, claws=3, l=(34, 32))
    hc = T(128, 28)
    head(cv, hc, 12.5, 15, skin=ZSKIN, dead=True, mouth=pose.get("mouth", 0), glow=(236, 212, 70))
    hair_short(cv, hc, (44, 48, 38), "bald")
    zombie_face_damage(cv, hc, 12.5, 15)
    return cv


# ------------------------------------------------------------------ ZOMBIE GENDUT
def gendut_pose(name):
    P = {
        "idle_0": dict(hands=[(12, 66), (12, 66)]),
        "idle_1": dict(hands=[(18, 66), (18, 66)], dy=2),
        "walk_0": dict(hands=[(14, 62), (20, 72)], foot=[(0, -9), (0, 0)]),
        "walk_1": dict(hands=[(16, 66), (16, 66)]),
        "walk_2": dict(hands=[(20, 72), (14, 62)], foot=[(0, 0), (0, -9)]),
        "walk_3": dict(hands=[(16, 66), (16, 66)]),
        "shoot_0": dict(hands=[(38, -2), (38, -2)], mouth=1),
        "shoot_1": dict(hands=[(2, 40), (2, 40)], mouth=1, dy=4),
        "jump_0": dict(hands=[(14, 62), (14, 62)], dy=16, knee=8, foot=[(-4, 0), (4, 0)]),
        "jump_1": dict(hands=[(40, 6), (40, 6)], dy=-12, knee=12, foot=[(-6, -18), (6, -14)], mouth=1),
        "skill_0": dict(hands=[(-30, -10), (-30, -10)], mouth=1, dy=3),
        "skill_1": dict(hands=[(-26, -6), (-28, -16)], mouth=1, dy=5),
    }
    return P[name]


def gendut(pose):
    cv = Cv()
    dy = pose.get("dy", 0)

    def T(x, y):
        t = max(0.0, min(1.0, (190 - y) / 140.0))
        return (x, y + dy * (0.6 + 0.4 * t))
    legs(cv, T, pose, (70, 62, 54), (28, 24, 22), hipy=176, base=232, w=(32, 24, 16), sep=24, ragged=True, skin=ZSKIN_D)
    skin = (132, 152, 112)
    bc = T(128, 134)
    cv.part(f_ell(bc, 70, 62), skin, r=14, light=0.75, edge=0.6)
    cv.part(f_ell(T(128, 118), 56, 40), shade(skin, 1.06), r=10, edge=0.3)
    cloth = (122, 120, 108)
    cv.part(f_poly([T(60, 112), T(196, 112), T(204, 190), T(186, 176), T(172, 198), T(156, 178), T(142, 200), T(128, 180), T(112, 200), T(98, 178), T(84, 198), T(70, 176), T(54, 190)]),
            cloth, r=9, light=0.55, clip=np.asarray(cv.mask(f_ell(bc, 70, 62)), np.float32) / 255.0)
    blotches(cv, 12, (62, 112, 196, 190), (3, 9), BLOOD, 0.6, 17, 1.6)
    blotches(cv, 16, (62, 112, 196, 190), (3, 8), (60, 56, 48), 0.35, 18, 1.6)
    cv.part(f_ell(T(128, 150), 8, 6), shade(skin, 0.7), r=2, edge=0.4)   # pusar menyembul
    for k in range(4):
        line_decal(cv, [T(82 + k * 3, 108 + k * 9), T(104 + k * 3, 116 + k * 9)], (90, 110, 74), 1.6, 0.6, 0.8)   # lipatan perut
    # lengan tebal
    for i, s in enumerate((-1, 1)):
        Sh = T(128 + s * 58, 96)
        el, hand, dr = ik(Sh, pose["hands"][i], 32, 32, s)
        cv.part(f_limb(Sh, el, 30, 24), skin, r=7, light=0.7)
        cv.part(f_limb(el, hand, 24, 19), skin, r=6, light=0.7)
        blotches(cv, 3, (min(Sh[0], hand[0]) - 6, Sh[1], max(Sh[0], hand[0]) + 6, hand[1]), (2, 5), BLOOD, 0.6, 30 + i, 1.0)
        cv.part(f_ell(hand, 15, 14), shade(skin, 1.05), r=5, light=0.75)
        for k in (-1, 0, 1):
            line_decal(cv, [(hand[0] + k * 6, hand[1] - 9), (hand[0] + k * 6, hand[1] + 1)], (78, 98, 64), 1.3, 0.6)
    hc = T(128, 58)
    head(cv, hc, 15, 15.5, skin=skin, dead=True, mouth=pose.get("mouth", 0), glow=(238, 210, 66))
    hair_short(cv, hc, (40, 44, 34), "bald", ry=15)
    zombie_face_damage(cv, hc, 15, 15.5, seed=8)
    return cv


# ------------------------------------------------------------------ ZOMBIE SUSTER
def suster_pose(name):
    P = {
        "idle_0": dict(hands=[(20, 56), (20, 56)]),
        "idle_1": dict(hands=[(24, 60), (24, 60)], dy=1),
        "walk_0": dict(hands=[(18, 50), (26, 62)], foot=[(0, -9), (0, 0)], lean=-3),
        "walk_1": dict(hands=[(20, 56), (20, 56)]),
        "walk_2": dict(hands=[(26, 62), (18, 50)], foot=[(0, 0), (0, -9)], lean=3),
        "walk_3": dict(hands=[(20, 56), (20, 56)]),
        "shoot_0": dict(hands=[(50, -28), (50, -28)], mouth=1),
        "shoot_1": dict(hands=[(-3, 28), (-3, 28)], mouth=1, lean=6, dy=4),
        "jump_0": dict(hands=[(16, 58), (16, 58)], dy=16, knee=5, foot=[(-3, 0), (3, 0)]),
        "jump_1": dict(hands=[(44, -24), (44, -24)], dy=-10, knee=9, foot=[(-5, -20), (5, -14)], mouth=1),
        "skill_0": dict(hands=[(54, -6), (54, -6)], mouth=1),
        "skill_1": dict(hands=[(50, -18), (50, -18)], mouth=1, dy=-2),
    }
    return P[name]


def suster(pose):
    cv = Cv()
    T = T_factory(pose)
    SK = (190, 200, 184)
    DR = (232, 232, 226)
    hc = T(128, 28)
    # rambut panjang belakang
    cv.part(f_poly([(hc[0] - 15, hc[1] - 2), (hc[0] + 15, hc[1] - 2), (hc[0] + 21, hc[1] + 52), (hc[0] + 12, hc[1] + 64), (hc[0] + 2, hc[1] + 50),
                    (hc[0] - 6, hc[1] + 62), (hc[0] - 14, hc[1] + 50), (hc[0] - 21, hc[1] + 54)]), (40, 30, 32), r=4, tex=0.3)
    # kaki pucat + sepatu
    legs(cv, T, pose, SK, (200, 200, 204), hipy=150, w=(15, 12, 9), base=230, sep=10)
    # gaun
    dress = [T(104, 58), T(152, 58), T(156, 80), T(152, 112), T(170, 166), T(158, 174), T(148, 166), T(138, 174), T(128, 166), T(118, 174), T(108, 166), T(98, 174), T(86, 166), T(104, 112), T(100, 80)]
    cv.part(f_poly(dress), DR, r=8, light=0.5, tex=0.05)
    for x, y, rx, ry in ((112, 120, 10, 7), (146, 130, 8, 12), (126, 150, 13, 6), (106, 96, 5, 9), (140, 90, 6, 5), (120, 164, 9, 4)):
        p = T(x, y)
        decal_simple(cv, f_ell(p, rx, ry), BLOOD, 0.85, 1.1)
    line_decal(cv, [T(88, 166), T(168, 166)], BLOOD, 2.2, 0.85)
    for k in range(5):
        line_decal(cv, [T(112 + k * 7, 120), T(110 + k * 8, 160)], (192, 192, 186), 1.0, 0.5, 0.6)   # lipatan gaun
    p = T(128, 82)
    cv.part(f_rect(p, 5, 18, 0.6), (178, 26, 30), r=0.8, edge=0.4)
    cv.part(f_rect(p, 18, 5, 0.6), (178, 26, 30), r=0.8, edge=0.4)
    cv.part(f_rect(T(128, 128), 40, 3.4, 1), (196, 196, 190), r=1, edge=0.4)
    arms(cv, T, pose, DR, SK, sleeve_len=0.5, claws=3, l=(32, 30), wid=(13, 9))
    head(cv, hc, 12, 14.6, skin=SK, dead=True, mouth=pose.get("mouth", 0), glow=(228, 64, 52))
    cx, cy = hc
    cv.part(f_poly([(cx - 13, cy - 2), (cx - 8, cy - 10), (cx, cy - 4), (cx + 8, cy - 11), (cx + 13, cy - 2), (cx + 13, cy - 11), (cx, cy - 15), (cx - 13, cy - 11)]), (40, 30, 32), r=2, tex=0.3)
    cv.part(f_poly([(cx - 12, cy - 12), (cx + 12, cy - 12), (cx + 9, cy - 28), (cx - 9, cy - 28)]), DR, r=3, edge=0.55)   # topi suster
    cv.part(f_rect((cx, cy - 20), 4, 12, 0.5), (178, 26, 30), r=0.7, edge=0.4)
    cv.part(f_rect((cx, cy - 20), 12, 4, 0.5), (178, 26, 30), r=0.7, edge=0.4)
    zombie_face_damage(cv, hc, 12, 14.6, seed=14)
    return cv


# ------------------------------------------------------------------ SAMURAI
def samurai_pose(name):
    P = {
        "idle_0": dict(), "idle_1": dict(dy=1),
        "walk_0": dict(foot=[(0, -9), (0, 0)], dy=1), "walk_1": dict(), "walk_2": dict(foot=[(0, 0), (0, -9)], dy=1), "walk_3": dict(),
        "shoot_0": dict(sword="up"), "shoot_1": dict(sword="side", lean=-4),
        "jump_0": dict(dy=14, knee=6, foot=[(-3, 0), (3, 0)]),
        "jump_1": dict(dy=-10, knee=10, foot=[(-6, -20), (6, -14)]),
        "skill_0": dict(sword="up", glow=True), "skill_1": dict(sword="side", glow=True, lean=-4),
    }
    return P[name]


def samurai(pose):
    cv = Cv()
    T = T_factory(pose)
    legs(cv, T, pose, (30, 34, 56), (26, 22, 20), sep=12, w=(23, 18, 13))
    # hakama lebar
    cv.part(f_poly([T(102, 130), T(154, 130), T(160, 190), T(96, 190)]), (36, 40, 66), r=6, light=0.5, clip=None)
    for x in (112, 128, 144):
        line_decal(cv, [T(x, 134), T(x + (x - 128) * 0.3, 186)], (18, 20, 36), 1.4, 0.6)
    red = (150, 34, 34)
    gold = (206, 168, 62)
    cv.part(f_poly(torso_poly(T, sh=30, wa=23, hip=25)), red, r=7, light=0.65)
    for k in range(7):   # pelat armor
        y = 70 + k * 8
        cv.part(f_rect(T(128, y), 44, 5.4, 1), shade(red, 0.9 + 0.04 * (k % 2)), r=1.2, edge=0.55, light=0.6)
        line_decal(cv, [T(106, y + 3.2), T(150, y + 3.2)], gold, 0.9, 0.8, 0.3)
    cv.part(f_poly([T(112, 56), T(144, 56), T(138, 70), T(128, 76), T(118, 70)]), (32, 24, 26), r=2, edge=0.5)
    cv.part(f_poly([T(98, 112), T(158, 112), T(164, 142), T(92, 142)]), shade(red, 0.8), r=4, edge=0.55)   # kusazuri
    for x in range(96, 164, 11):
        line_decal(cv, [T(x, 114), T(x - 1, 140)], gold, 0.8, 0.7, 0.3)
    for s in (-1, 1):   # pelindung bahu
        cv.part(f_poly([T(128 + s * 24, 56), T(128 + s * 46, 62), T(128 + s * 50, 84), T(128 + s * 26, 76)]), shade(red, 0.95), r=4, edge=0.55)
        for k in range(3):
            line_decal(cv, [T(128 + s * 26, 62 + k * 7), T(128 + s * 48, 66 + k * 7)], gold, 0.8, 0.7, 0.3)
    # lengan + pedang
    sw = pose.get("sword", "")
    if sw == "up":
        tg = [(34, -22), (30, -10)]
    elif sw == "side":
        tg = [(54, 20), (50, 14)]
    else:
        tg = [(20, 56), (26, 50)]
    arm_info = arms(cv, T, dict(hands=tg), (40, 30, 34), (200, 150, 116), glove=(34, 28, 26), sleeve_len=1.0, l=(32, 30), wid=(14, 11), sx=32)
    hc = T(128, 28)
    head(cv, hc, 12.5, 15, skin=(196, 148, 112), eye=(40, 28, 22))
    cx, cy = hc
    cv.part(f_poly([(cx - 13, cy + 2), (cx + 13, cy + 2), (cx + 11, cy + 15), (cx, cy + 18), (cx - 11, cy + 15)]), red, r=2.5, tex=0.2)   # masker merah
    cv.part(f_poly([(cx - 16, cy - 1), (cx - 14, cy - 12), (cx - 6, cy - 19), (cx + 6, cy - 19), (cx + 14, cy - 12), (cx + 16, cy - 1), (cx + 14, cy + 2), (cx - 14, cy + 2)]), (34, 30, 34), r=3.5)   # kabuto
    cv.part(f_poly([(cx - 5, cy - 17), (cx - 12, cy - 33), (cx - 1, cy - 19)]), gold, r=1, edge=0.4)
    cv.part(f_poly([(cx + 5, cy - 17), (cx + 12, cy - 33), (cx + 1, cy - 19)]), gold, r=1, edge=0.4)
    decal_simple(cv, f_rect((cx, cy - 1), 26, 3, 0.5), gold, 0.9, 0.3)
    if sw:
        hx, hy = arm_info[1][2]
        if sw == "up":
            a, b = (hx, hy), (hx + 30, hy - 62)
        else:
            a, b = (hx, hy), (hx + 64, hy - 20)
        # bilah
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        cv.part(f_limb(a, b, 4.2, 2.6), (206, 212, 224), r=1.2, light=0.9, edge=0.5)
        line_decal(cv, [a, b], (250, 252, 255), 0.9, 0.7, 0.2)
        cv.part(f_limb((a[0] - 9 * math.cos(ang), a[1] - 9 * math.sin(ang)), a, 5), (30, 26, 28), r=1.2, edge=0.5)
        cv.part(f_ell(a, 5, 2.8), gold, r=1, edge=0.4)
    return cv


# ------------------------------------------------------------------ render semua frame
KINDS = {
    "blue": (lambda n: gun_pose(n), lambda p: soldier(p, "blue"), False),
    "red": (lambda n: gun_pose(n), lambda p: soldier(p, "red"), False),
    "hero": (lambda n: gun_pose(n), hero, False),
    "civil": (lambda n: gun_pose(n), lambda p: civil(p, "civil"), False),
    "civil2": (lambda n: gun_pose(n), lambda p: civil(p, "civil2"), False),
    "civil3": (lambda n: gun_pose(n), lambda p: civil(p, "civil3"), False),
    "zombie": (zombie_pose, zombie, True),
    "gendut": (gendut_pose, gendut, True),
    "suster": (suster_pose, suster, True),
    "samurai": (samurai_pose, samurai, True),
}


def glow_layer(color, center, r, alpha=120, blur=18):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x, y = center[0] * SS, center[1] * SS
    d.ellipse([x - r * SS, y - r * SS, x + r * SS, y + r * SS], fill=tuple(color[:3]) + (alpha,))
    return im.filter(ImageFilter.GaussianBlur(blur * SS / 2))


def tilt(img, deg):
    big = Image.new("RGBA", (N * 2, N * 2), (0, 0, 0, 0))
    big.paste(img, (N // 2, N // 2))
    r = big.rotate(deg, resample=Image.BICUBIC, center=(N, (240 + W // 2) * SS))
    bb = r.getbbox()
    crop = r.crop(bb)
    sc = min(1.0, (N - 8 * SS) / crop.width, (N - 6 * SS) / crop.height)
    if sc < 1.0:
        crop = crop.resize((int(crop.width * sc), int(crop.height * sc)), Image.LANCZOS)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(crop, ((N - crop.width) // 2, N - 4 * SS - crop.height))
    return out


def with_skill_fx(kind, name, im):
    if not name.startswith("skill"):
        return im
    k = int(name[-1])
    if kind == "zombie":
        bg = glow_layer((255, 60, 40), (128, 130), 105 + k * 8, 110)
    elif kind == "gendut":
        R = 118 + k * 6
        bg = glow_layer((70, 140, 255), (128, 140), R - 6, 70, 10)
        d = ImageDraw.Draw(im)
        d.ellipse([(128 - R) * SS, (140 - R) * SS, (128 + R) * SS, (140 + R) * SS], outline=(150, 205, 255, 230), width=5 * SS)
    elif kind == "suster":
        bg = glow_layer((90, 230, 120), (128, 150), 112, 140)
        a = im.split()[3].point(lambda v: int(v * 0.65))
        im.putalpha(a)
        for (x, y, r) in ((70, 205, 34), (190, 200, 38), (128, 232, 44), (96, 150, 26), (170, 120, 28)):
            im = Image.alpha_composite(im, glow_layer((120, 255, 150), (x + k * 8, y - k * 6), r, 110, 14))
    else:   # samurai
        bg = glow_layer((120, 200, 255), (128, 130), 104 + k * 8, 100)
    return Image.alpha_composite(bg, im)


def down(im):
    return im.resize((W, W), Image.LANCZOS)


def build(kind):
    posef, drawf, full = KINDS[kind]
    names = ["idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3", "shoot_0", "shoot_1"]
    if full:
        names += ["jump_0", "jump_1", "skill_0", "skill_1"]
    folder = os.path.join(AS, "char_" + kind)
    os.makedirs(folder, exist_ok=True)
    base_big = None
    for n in names:
        cv = drawf(posef(n))
        im = cv.image()
        if n == "idle_0":
            base_big = im.copy()
        im = with_skill_fx(kind, n, im)
        down(im).save(os.path.join(folder, n + ".png"))
    for i, a in enumerate((22, 52, 80, 92)):
        down(tilt(base_big, a)).save(os.path.join(folder, "die_%d.png" % i))
    print("ok", kind)
    return base_big


# ------------------------------------------------------------------ potret
def biohazard(d, cx, cy, r, col):
    for a in (90, 210, 330):
        x = cx + math.cos(math.radians(a)) * r * 0.55
        y = cy - math.sin(math.radians(a)) * r * 0.55
        d.ellipse([x - r * 0.5, y - r * 0.5, x + r * 0.5, y + r * 0.5], outline=col, width=max(2, int(r * 0.16)))
    d.ellipse([cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22], fill=col)
    d.ellipse([cx - r * 1.12, cy - r * 1.12, cx + r * 1.12, cy + r * 1.12], outline=col, width=max(2, int(r * 0.1)))


def portrait(big, box, tint, size=(300, 360), badge=True):
    PW, PH = size
    crop = big.crop(tuple(int(v * SS) for v in box))
    sc = min(PW / crop.width, PH / crop.height)
    crop = crop.resize((max(1, int(crop.width * sc)), max(1, int(crop.height * sc))), Image.LANCZOS)
    yy, xx = np.mgrid[0:PH, 0:PW]
    dist = np.sqrt(((xx - PW / 2) / (PW * 0.7)) ** 2 + ((yy - PH * 0.45) / (PH * 0.7)) ** 2)
    arr = np.zeros((PH, PW, 4), dtype=np.uint8)
    f = np.clip(1.0 - dist, 0, 1)
    for ch in range(3):
        arr[..., ch] = (12 + f * tint[ch]).astype(np.uint8)
    arr[..., 3] = 255
    bg = Image.fromarray(arr, "RGBA")
    bg.alpha_composite(crop, ((PW - crop.width) // 2, PH - crop.height))
    if badge:
        biohazard(ImageDraw.Draw(bg), PW - 34, 34, 15, (240, 200, 30, 255))
        sh = np.zeros((PH, PW, 4), dtype=np.uint8)
        g = np.clip((yy - PH * 0.62) / (PH * 0.38), 0, 1)
        sh[..., 3] = (g * 200).astype(np.uint8)
        bg.alpha_composite(Image.fromarray(sh, "RGBA"))
    return bg


def build_portraits(bases):
    boxes = {"zombie": (60, 0, 196, 120), "gendut": (44, 8, 212, 130), "suster": (54, 0, 202, 120)}
    portrait(bases["zombie"], boxes["zombie"], (150, 40, 30)).save(os.path.join(AS, "portrait_biasa.png"))
    portrait(bases["gendut"], boxes["gendut"], (40, 110, 150)).save(os.path.join(AS, "portrait_gendut.png"))
    portrait(bases["suster"], boxes["suster"], (40, 140, 60)).save(os.path.join(AS, "portrait_suster.png"))
    portrait(bases["zombie"], boxes["zombie"], (120, 20, 120)).save(os.path.join(AS, "portrait_induk.png"))
    portrait(bases["hero"], (60, 0, 196, 120), (150, 110, 40), badge=False).save(os.path.join(AS, "portrait_hero.png"))
    portrait(bases["civil"], (60, 0, 196, 120), (60, 90, 130), badge=False).save(os.path.join(AS, "portrait_civil.png"))
    # foto kecil HUD (kotak)
    for nm, key, box, tint in (("hero", "hero", (84, 4, 172, 80), (150, 110, 40)), ("civil", "civil", (84, 4, 172, 80), (60, 90, 130)),
                               ("biasa", "zombie", (84, 4, 172, 80), (150, 40, 30)), ("induk", "zombie", (84, 4, 172, 80), (120, 20, 120)),
                               ("gendut", "gendut", (66, 14, 190, 106), (40, 110, 150)), ("samurai", "samurai", (80, 0, 176, 78), (150, 40, 40)), ("suster", "suster", (80, 0, 176, 78), (40, 140, 60))):
        portrait(bases[key], box, tint, size=(128, 128), badge=False).save(os.path.join(AS, "face_%s.png" % nm))
    print("ok portraits")


# ------------------------------------------------------------------ tangan first-person (zombie / gendut / suster)
def fp_hand(cv, cx, spread, tilt_deg, skin, claw, cloth, fist=False, blood=True, seed=1):
    """satu lengan dari bawah layar; (cx,bottom)=pangkal lengan, tegak lalu miring"""
    H = cv.h
    ang = math.radians(tilt_deg)
    ux, uy = math.sin(ang), -math.cos(ang)
    base = (cx, H + 20)
    wrist = (cx + ux * 290, H + 20 + uy * 290)
    palm = (cx + ux * 340, H + 20 + uy * 340)
    f = lambda p: p
    def P(p): return (p[0] * 1.0, p[1] * 1.0)
    def limb(a, b, w1, w2):
        def g(d):
            an = math.atan2(b[1] - a[1], b[0] - a[0]) + math.pi / 2
            ox, oy = math.cos(an), math.sin(an)
            d.polygon([(a[0] + ox * w1 / 2, a[1] + oy * w1 / 2), (b[0] + ox * w2 / 2, b[1] + oy * w2 / 2), (b[0] - ox * w2 / 2, b[1] - oy * w2 / 2), (a[0] - ox * w1 / 2, a[1] - oy * w1 / 2)], fill=255)
            for p, w in ((a, w1), (b, w2)):
                d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=255)
        return g
    cv.part(limb(base, wrist, 150, 104), skin, r=22, light=0.7, tex=0.12)
    # lengan baju robek di bagian bawah
    cv.part(limb(base, (cx + ux * 90, H + 20 + uy * 90), 170, 150), cloth, r=18, light=0.55, tex=0.14)
    rs = np.random.RandomState(seed)
    if blood:
        for _ in range(9):
            x = cx + ux * rs.uniform(20, 300) + rs.uniform(-40, 40)
            y = H + 20 + uy * rs.uniform(20, 300)
            rr = rs.uniform(10, 26)
            decal_simple(cv, lambda d, x=x, y=y, rr=rr: d.ellipse([x - rr, y - rr * 0.7, x + rr, y + rr * 0.7], fill=255), (110, 14, 16), 0.7, 3)
        for _ in range(12):
            x = cx + ux * rs.uniform(60, 300) + rs.uniform(-45, 45)
            y = H + 20 + uy * rs.uniform(60, 300)
            decal_simple(cv, lambda d, x=x, y=y: d.ellipse([x - 12, y - 9, x + 12, y + 9], fill=255), (70, 60, 50), 0.35, 4)
    # telapak
    if fist:
        cv.part(f_ell_px(palm, 74, 70), skin, r=18, light=0.8)
        for k in range(4):
            fx = palm[0] + (k - 1.5) * 34
            cv.part(f_ell_px((fx, palm[1] - 46), 17, 20), shade(skin, 1.05), r=5, light=0.8)
        return
    cv.part(f_ell_px(palm, 62, 56), skin, r=16, light=0.8)
    for k in range(4):
        a = ang + (k - 1.5) * spread
        base_f = (palm[0] + math.sin(a) * 36, palm[1] - math.cos(a) * 36)
        mid = (base_f[0] + math.sin(a) * 62, base_f[1] - math.cos(a) * 62)
        tip = (mid[0] + math.sin(a + 0.1 * (k - 1.5)) * 52, mid[1] - math.cos(a + 0.1 * (k - 1.5)) * 52)
        cv.part(limb(base_f, mid, 26, 21), skin, r=6, light=0.8)
        cv.part(limb(mid, tip, 21, 16), skin, r=5, light=0.8)
        for q in (mid,):
            decal_simple(cv, lambda d, q=q: d.ellipse([q[0] - 12, q[1] - 5, q[0] + 12, q[1] + 5], fill=255), (50, 36, 30), 0.5, 2)
        ex = (tip[0] + math.sin(a) * 40, tip[1] - math.cos(a) * 40)
        px, py = math.cos(a) * 8, math.sin(a) * 8
        cv.part(lambda d, tip=tip, ex=ex, px=px, py=py: d.polygon([(tip[0] + px, tip[1] + py), ex, (tip[0] - px, tip[1] - py)], fill=255), claw, r=2, edge=0.55, light=0.7)
    a = ang - 2.1
    tb = (palm[0] + math.sin(a) * 40, palm[1] - math.cos(a) * 40)
    tt = (tb[0] + math.sin(a) * 90, tb[1] - math.cos(a) * 90)
    cv.part(limb(tb, tt, 24, 18), skin, r=5, light=0.8)
    ex = (tt[0] + math.sin(a) * 38, tt[1] - math.cos(a) * 38)
    cv.part(lambda d: d.polygon([(tt[0] + 7, tt[1] + 5), ex, (tt[0] - 7, tt[1] - 5)], fill=255), claw, r=2, edge=0.55)


def f_ell_px(c, rx, ry):
    def f(d):
        d.ellipse([c[0] - rx, c[1] - ry, c[0] + rx, c[1] + ry], fill=255)
    return f


def build_hands():
    global SS
    saved = SS
    SS = 1   # fungsi bantu memakai skala piksel langsung untuk FP
    sets = {
        "zombie_hands": dict(skin=(112, 138, 98), claw=(206, 196, 166), cloth=(58, 76, 100), fist=False),
        "gendut_fists": dict(skin=(124, 146, 104), claw=(206, 196, 166), cloth=(110, 108, 98), fist=True),
        "suster_hands": dict(skin=(190, 202, 184), claw=(150, 30, 34), cloth=(226, 226, 220), fist=False),
    }
    variants = {0: (-6, 0.34, 6), 1: (6, 0.26, -6)}
    for nm, cfg in sets.items():
        for fi in (0, 1):
            im = Image.new("RGBA", (781, 474), (0, 0, 0, 0))
            for side in (0, 1):
                cv = Cv(390, 474)
                tl, sp, off = variants[fi]
                tl = tl if side == 0 else -tl
                fp_hand(cv, 195 + (off if side == 0 else -off), sp, tl + (-5 if side == 0 else 5), cfg["skin"], cfg["claw"], cfg["cloth"], fist=cfg["fist"], seed=fi * 3 + side + 1)
                im.alpha_composite(cv.image(), (side * 391, 0))
            im.save(os.path.join(AS, "%s_%d.png" % (nm, fi)))
    SS = saved
    # varian loncat (2) & skill (3) dibuat dari frame 0/1 seperti versi lama
    import importlib.util
    spec = importlib.util.spec_from_file_location("gen_chars", os.path.join(HERE, "gen_chars.py"))
    gc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gc)
    gc.hand_variants("zombie", ("zombie_hands_0.png", "zombie_hands_1.png"), "zombie_hands", (255, 70, 50, 255), "claw")
    gc.hand_variants("gendut", ("gendut_fists_0.png", "gendut_fists_1.png"), "gendut_fists", (80, 150, 255, 255), "guard")
    gc.hand_variants("suster", ("suster_hands_0.png", "suster_hands_1.png"), "suster_hands", (90, 230, 120, 255), "open")
    print("ok hands")


if __name__ == "__main__":
    import sys
    only = sys.argv[1:] or list(KINDS) + ["hands", "portraits"]
    bases = {}
    for k in KINDS:
        if k in only:
            bases[k] = build(k)
    if "hands" in only:
        build_hands()
    if "portraits" in only or len(bases) == len(KINDS):
        for k in ("zombie", "gendut", "suster", "hero", "civil", "samurai"):
            if k not in bases:
                bases[k] = KINDS[k][1](KINDS[k][0]("idle_0")).image()
        build_portraits(bases)
