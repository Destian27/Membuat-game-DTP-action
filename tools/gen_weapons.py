#!/usr/bin/env python3
"""Generator gambar senjata baru v0.0.2.5 (gaya vektor datar sama seperti weapon.png).
Hasil: assets/m4a1_fp.png, deagle_fp.png, karambit_fp.png  (first-person 781x474)
       assets/icon_m4a1.png, icon_deagle.png, icon_karambit.png (ikon 256x128)
Jalankan:  python3 tools/gen_weapons.py   (butuh Pillow)
Mau ganti tampilan? Timpa PNG dengan nama yang sama (muzzle di weapons.gd menyesuaikan).
"""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
SS = 2                      # supersample
FW, FH = 781, 474
OLIVE = (74, 88, 56, 255)
OLIVE_L = (96, 112, 76, 255)
GLOVE = (34, 34, 38, 255)
OUTLINE = (18, 18, 22, 255)


def P(pts):
    return [(x * SS, y * SS) for x, y in pts]


def poly(d, pts, fill, outline=OUTLINE):
    d.polygon(P(pts), fill=fill)
    if outline:
        d.line(P(pts + [pts[0]]), fill=outline, width=SS * 2, joint="curve")


def rect(d, x0, y0, x1, y1, fill, outline=OUTLINE, r=0):
    box = [x0 * SS, y0 * SS, x1 * SS, y1 * SS]
    if r:
        d.rounded_rectangle(box, radius=r * SS, fill=fill, outline=outline, width=SS * 2)
    else:
        d.rectangle(box, fill=fill, outline=outline, width=SS * 2)


# ------------------------------------------------------------------ senjata (horizontal, moncong di kiri)
def draw_m4a1(d):
    dark, mid, lite = (30, 32, 36, 255), (52, 56, 64, 255), (92, 98, 108, 255)
    rect(d, 10, 118, 70, 142, dark, r=3)                              # flash hider
    rect(d, 70, 126, 250, 138, mid)                                    # laras
    poly(d, [(250, 108), (470, 104), (470, 160), (250, 160)], mid)     # handguard
    for x in range(268, 460, 26):
        rect(d, x, 118, x + 12, 148, dark, outline=None)              # lubang ventilasi
    rect(d, 262, 108, 462, 115, lite, outline=None)
    poly(d, [(470, 92), (640, 92), (650, 168), (470, 168)], dark)      # receiver
    rect(d, 480, 100, 630, 108, lite, outline=None)
    rect(d, 380, 80, 640, 92, dark)                                    # rail atas
    rect(d, 520, 52, 610, 80, mid, r=4)                                # optik
    rect(d, 528, 58, 548, 74, (80, 200, 255, 255), outline=None)       # lensa
    poly(d, [(650, 104), (860, 120), (860, 190), (650, 170)], mid)     # popor
    poly(d, [(500, 168), (570, 168), (588, 290), (518, 290)], dark)    # magasin
    rect(d, 506, 176, 520, 280, lite, outline=None)
    poly(d, [(610, 168), (668, 168), (690, 262), (636, 262)], dark)    # gagang
    rect(d, 58, 108, 70, 126, dark, outline=None)                      # pisir depan
    return (10, 130)


def draw_deagle(d):
    sil, sil2, dark = (170, 176, 186, 255), (210, 216, 224, 255), (34, 34, 40, 255)
    rect(d, 30, 82, 520, 156, sil, r=8)                                # slide perak
    rect(d, 44, 90, 500, 100, sil2, outline=None)
    rect(d, 20, 100, 60, 140, dark, r=3)                               # moncong
    for x in range(430, 506, 14):
        rect(d, x, 96, x + 6, 148, (110, 116, 126, 255), outline=None)
    rect(d, 36, 156, 420, 190, dark, r=4)                              # rangka bawah
    poly(d, [(410, 156), (520, 156), (505, 300), (400, 300)], (60, 40, 26, 255))  # gagang kayu
    rect(d, 420, 168, 430, 290, (90, 62, 40, 255), outline=None)
    d.arc(P([(250, 150), (330, 235)]) [0] + P([(250, 150), (330, 235)])[1], 0, 180, fill=OUTLINE, width=SS * 4)
    rect(d, 502, 74, 520, 90, dark, outline=None)                      # pisir belakang
    rect(d, 26, 72, 44, 84, dark, outline=None)                        # pisir depan
    return (20, 118)


def draw_karambit(d):
    steel, steel2, dark, red = (196, 204, 214, 255), (235, 240, 246, 255), (28, 28, 32, 255), (200, 40, 40, 255)
    # bilah melengkung (karambit)
    pts = [(30, 190), (60, 120), (140, 70), (250, 56), (330, 70), (330, 100), (250, 98), (180, 120), (120, 165), (80, 215)]
    poly(d, pts, steel)
    poly(d, [(60, 150), (140, 96), (240, 80), (240, 92), (150, 112), (90, 165)], steel2, outline=None)
    rect(d, 320, 78, 520, 130, dark, r=14)                             # gagang
    for x in range(340, 510, 22):
        rect(d, x, 86, x + 8, 122, red, outline=None)
    d.ellipse(P([(500, 70), (590, 160)])[0] + P([(500, 70), (590, 160)])[1], outline=OUTLINE, fill=(0, 0, 0, 0), width=SS * 7)  # cincin jari
    return (30, 190)


# ------------------------------------------------------------------ penyusun gambar
def render_weapon(draw_fn, w=900, h=330):
    layer = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    mz = draw_fn(d)
    return layer, (mz[0] * SS, mz[1] * SS)


def rotate_with_point(img, pt, deg):
    """putar searah jarum jam sebesar deg (PIL: sudut negatif) dan kembalikan titik yang ikut berputar"""
    th = math.radians(-deg)
    w, h = img.size
    cx, cy = w / 2.0, h / 2.0
    rot = img.rotate(-deg, resample=Image.BICUBIC, expand=True)
    nw, nh = rot.size
    dx, dy = pt[0] - cx, pt[1] - cy
    x2 = nw / 2.0 + dx * math.cos(th) + dy * math.sin(th)
    y2 = nh / 2.0 - dx * math.sin(th) + dy * math.cos(th)
    return rot, (x2, y2)


def hands(canvas, sleeves, gloves):
    d = ImageDraw.Draw(canvas)
    for pts in sleeves:
        d.polygon(P(pts), fill=OLIVE)
        d.line(P([pts[0], pts[-1]]), fill=OLIVE_L, width=SS * 3)
    for box in gloves:
        d.ellipse([box[0] * SS, box[1] * SS, box[2] * SS, box[3] * SS], fill=GLOVE, outline=OUTLINE, width=SS * 2)


def make_fp(name, draw_fn, deg, target_w, pos, sleeves, gloves, glove_front=True):
    canvas = Image.new("RGBA", (FW * SS, FH * SS), (0, 0, 0, 0))
    layer, mz = render_weapon(draw_fn)
    layer, mz = rotate_with_point(layer, mz, deg)
    bb = layer.getbbox()
    layer = layer.crop(bb)
    mz = (mz[0] - bb[0], mz[1] - bb[1])
    k = target_w * SS / layer.size[0]
    layer = layer.resize((int(layer.size[0] * k), int(layer.size[1] * k)), Image.LANCZOS)
    mz = (mz[0] * k, mz[1] * k)
    hands(canvas, sleeves, [] if glove_front else gloves)
    canvas.alpha_composite(layer, (int(pos[0] * SS), int(pos[1] * SS)))
    if glove_front:
        hands(canvas, [], gloves)
    out = canvas.resize((FW, FH), Image.LANCZOS)
    out.save(os.path.join(OUT, name + "_fp.png"))
    fx = (pos[0] * SS + mz[0]) / SS / FW
    fy = (pos[1] * SS + mz[1]) / SS / FH
    print("ok", name + "_fp.png", "muzzle=Vector2(%.3f, %.3f)" % (fx, fy))


def make_icon(name, draw_fn):
    layer, _ = render_weapon(draw_fn)
    layer = layer.crop(layer.getbbox())
    w, h = layer.size
    k = min(240 * SS / w, 110 * SS / h)
    layer = layer.resize((int(w * k), int(h * k)), Image.LANCZOS)
    icon = Image.new("RGBA", (256 * SS, 128 * SS), (0, 0, 0, 0))
    icon.alpha_composite(layer, ((256 * SS - layer.size[0]) // 2, (128 * SS - layer.size[1]) // 2))
    icon.resize((256, 128), Image.LANCZOS).save(os.path.join(OUT, "icon_" + name + ".png"))
    print("ok icon_" + name + ".png")


if __name__ == "__main__":
    RIGHT_SLEEVE = [(540, 380), (610, 322), (781, 474), (700, 474)]
    LEFT_SLEEVE = [(300, 300), (390, 250), (560, 474), (430, 474)]
    make_fp("m4a1", draw_m4a1, 20, 760, (10, 10), [LEFT_SLEEVE, RIGHT_SLEEVE],
            [(262, 190, 400, 280), (512, 296, 620, 400)])
    make_fp("deagle", draw_deagle, 18, 420, (215, 60), [LEFT_SLEEVE, RIGHT_SLEEVE],
            [(400, 250, 560, 370), (500, 330, 650, 430)])
    make_fp("karambit", draw_karambit, 25, 430, (230, 40), [LEFT_SLEEVE, RIGHT_SLEEVE],
            [(470, 150, 590, 250), (500, 330, 650, 430)])
    make_icon("m4a1", draw_m4a1)
    make_icon("deagle", draw_deagle)
    make_icon("karambit", draw_karambit)
