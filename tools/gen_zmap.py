#!/usr/bin/env python3
"""Generator tekstur peta mode Zombie "Kota Mati" (v0.0.2.4).
Jalankan: python3 tools/gen_zmap.py  (butuh numpy, scipy, pillow). Hasil: assets/z_*.png + assets/stage_zombie.png
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

A = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
rng = np.random.default_rng(11)


def fnoise(h, w, sigma, wrap=True):
    x = rng.standard_normal((h, w))
    x = gaussian_filter(x, sigma, mode="wrap" if wrap else "reflect")
    x = (x - x.mean()) / (x.std() + 1e-9)
    return x


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def tile_noise(size=256):
    return fnoise(size, size, 1.2) * 0.5 + fnoise(size, size, 4) * 0.8 + fnoise(size, size, 14) * 1.0


# ---- lantai: aspal retak gelap + noda darah
def floor():
    n = tile_noise()
    base = np.array([44, 44, 50], float)
    img = base[None, None, :] + n[..., None] * np.array([7, 7, 8])
    # retakan: garis acak yang membungkus (wrap) supaya tile mulus
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for _ in range(9):
        x, y = rng.integers(0, 256, 2)
        for _s in range(rng.integers(8, 20)):
            nx = x + rng.integers(-14, 15)
            ny = y + rng.integers(-14, 15)
            d.line([(x % 256, y % 256), (nx % 256, ny % 256)] if abs(nx - x) < 100 and abs(ny - y) < 100 else [], fill=(14, 14, 18), width=1)
            x, y = nx, ny
    img = np.asarray(im).astype(float)
    # noda darah
    b = fnoise(256, 256, 9)
    mask = np.clip((b - 1.25) * 2.2, 0, 1)
    blood = np.array([92, 10, 12], float)
    img = img * (1 - mask[..., None] * 0.85) + blood[None, None, :] * mask[..., None] * 0.85
    # garis jalan kuning pudar
    img[120:128, :, :] = img[120:128, :, :] * 0.5 + np.array([120, 100, 30]) * 0.5 * (fnoise(8, 256, 3)[..., None] > -0.3)
    to_img(img).save(os.path.join(A, "z_floor.png"))


# ---- dinding: beton lapuk dengan noda, lumut, dan papan
def wall():
    n = tile_noise()
    img = np.array([70, 66, 62], float)[None, None, :] + n[..., None] * np.array([9, 9, 9])
    # noda air menetes vertikal
    drip = fnoise(256, 256, (30, 2))
    img *= (1 - 0.35 * np.clip(drip, 0, 2)[..., None] * 0.5)
    # lumut hijau di bawah
    moss = fnoise(256, 256, 6)
    m = np.clip((moss - 0.9) * 1.5, 0, 1) * np.linspace(0, 1, 256)[:, None]
    img = img * (1 - m[..., None] * 0.6) + np.array([40, 80, 38])[None, None, :] * m[..., None] * 0.6
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # papan kayu menyilang
    for (x0, y0, x1, y1) in [(10, 40, 246, 86), (14, 110, 242, 70), (20, 190, 240, 150)]:
        d.polygon([(x0, y0), (x1, y1), (x1, y1 + 22), (x0, y0 + 22)], fill=(84, 58, 36), outline=(30, 20, 12))
        for k in range(0, 256, 28):
            d.ellipse([k, (y0 + (y1 - y0) * k / 256) + 7, k + 5, (y0 + (y1 - y0) * k / 256) + 12], fill=(30, 28, 28))
    # cap tangan darah
    for _ in range(3):
        x, y = rng.integers(30, 220), rng.integers(20, 200)
        d.ellipse([x, y, x + 18, y + 22], fill=(104, 12, 14))
        for k in range(4):
            d.line([(x + 3 + k * 4, y), (x + 2 + k * 4, y - 12)], fill=(104, 12, 14), width=3)
        d.line([(x + 8, y + 20), (x + 9, y + 50)], fill=(90, 10, 12), width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    im.save(os.path.join(A, "z_wall.png"))


# ---- bangkai mobil berkarat
def car():
    n = tile_noise()
    img = np.array([88, 46, 30], float)[None, None, :] + n[..., None] * np.array([12, 8, 6])
    rust = np.clip(fnoise(256, 256, 5) - 0.4, 0, 2)
    img = img * (1 - 0.3 * rust[..., None]) + np.array([120, 60, 20])[None, None, :] * 0.3 * rust[..., None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([0, 112, 255, 118], fill=(30, 20, 18))
    d.rectangle([0, 200, 255, 204], fill=(30, 20, 18))
    d.rectangle([20, 40, 120, 100], fill=(30, 40, 46), outline=(16, 16, 18))
    d.rectangle([136, 40, 236, 100], fill=(30, 40, 46), outline=(16, 16, 18))
    d.line([(30, 50), (60, 90)], fill=(120, 130, 140), width=1)
    d.line([(150, 48), (200, 96)], fill=(120, 130, 140), width=1)
    im.save(os.path.join(A, "z_car.png"))


# ---- barikade
def barricade():
    n = tile_noise()
    img = np.array([66, 46, 30], float)[None, None, :] + n[..., None] * np.array([10, 8, 6])
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    for y in range(0, 256, 32):
        d.rectangle([0, y + 2, 255, y + 29], fill=(92, 64, 40), outline=(30, 20, 12))
        for x in range(8, 256, 64):
            d.ellipse([x, y + 12, x + 5, y + 17], fill=(30, 28, 28))
    # kawat berduri
    for y in (40, 150):
        d.line([(0, y), (255, y + 6)], fill=(150, 150, 155), width=2)
        for x in range(10, 256, 24):
            d.line([(x - 4, y + 3), (x + 4, y - 4)], fill=(150, 150, 155), width=1)
            d.line([(x - 4, y - 4), (x + 4, y + 3)], fill=(150, 150, 155), width=1)
    im.save(os.path.join(A, "z_barricade.png"))


# ---- langit: merah darah + bulan besar + awan + siluet kota
def sky():
    W, H = 1024, 512
    yy = np.linspace(0, 1, H)[:, None]
    top = np.array([22, 4, 14], float)
    mid = np.array([110, 18, 20], float)
    bot = np.array([160, 60, 30], float)
    t = yy
    col = np.where(t < 0.55, top + (mid - top) * (t / 0.55), mid + (bot - mid) * ((t - 0.55) / 0.45))
    img = np.repeat(col[:, None, :], W, axis=1)
    clouds = fnoise(H, W, (14, 40))
    img *= (0.75 + 0.25 * np.clip(clouds, -1.5, 1.5)[..., None] * 0.5 + 0.12)
    # bulan
    cx, cy, r = 700, 150, 64
    Y, X = np.mgrid[0:H, 0:W]
    dist = np.hypot(X - cx, Y - cy)
    halo = np.exp(-((dist - r) / 70.0) ** 2) * (dist > r)
    img += halo[..., None] * np.array([120, 40, 30])
    moon = (dist <= r).astype(float)
    img = img * (1 - moon[..., None]) + moon[..., None] * np.array([235, 200, 170])
    crater = gaussian_filter(rng.standard_normal((H, W)), 5) * 40
    img += (moon * crater)[..., None] * np.array([1, 0.8, 0.7])
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # siluet kota mati di horizon
    x = 0
    while x < W:
        w = int(rng.integers(30, 90))
        h = int(rng.integers(40, 170))
        d.rectangle([x, H - 60 - h + 60, x + w, H], fill=(14, 6, 10))
        for wx in range(x + 6, x + w - 8, 14):
            for wy in range(H - h + 20, H - 20, 22):
                if rng.random() < 0.05:
                    d.rectangle([wx, wy, wx + 5, wy + 8], fill=(180, 120, 40))
        x += w + int(rng.integers(0, 10))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    # kelelawar/burung bangkai
    d = ImageDraw.Draw(im)
    for bx, by in [(300, 120), (340, 140), (560, 90), (880, 200)]:
        d.line([(bx - 10, by), (bx, by - 5), (bx + 10, by)], fill=(10, 4, 8), width=2)
    im.save(os.path.join(A, "z_sky.png"))


# ---- thumbnail peta untuk lobi (360x200)
def thumb():
    W, H = 360, 200
    sky_im = Image.open(os.path.join(A, "z_sky.png")).resize((W, H))
    im = sky_im.copy()
    d = ImageDraw.Draw(im)
    d.polygon([(0, 150), (W, 150), (W, H), (0, H)], fill=(34, 34, 42))
    d.polygon([(0, 150), (W, 150), (W, 156), (0, 156)], fill=(20, 20, 26))
    # mobil rusak
    d.rectangle([60, 120, 150, 152], fill=(96, 50, 32), outline=(16, 8, 8))
    d.rectangle([76, 104, 134, 124], fill=(36, 46, 54), outline=(16, 8, 8))
    d.ellipse([70, 144, 90, 164], fill=(16, 16, 18))
    d.ellipse([122, 144, 142, 164], fill=(16, 16, 18))
    # barikade
    for k in range(3):
        d.rectangle([220, 118 + k * 12, 300, 128 + k * 12], fill=(92, 64, 40), outline=(30, 20, 12))
    # siluet zombie
    for zx, zs in [(185, 1.0), (205, 0.9), (330, 1.1), (30, 0.8)]:
        b = 150
        d.ellipse([zx - 6 * zs, b - 52 * zs, zx + 6 * zs, b - 40 * zs], fill=(70, 120, 60))
        d.rectangle([zx - 7 * zs, b - 40 * zs, zx + 7 * zs, b - 16 * zs], fill=(40, 60, 90))
        d.line([(zx - 7 * zs, b - 36 * zs), (zx - 22 * zs, b - 40 * zs)], fill=(70, 120, 60), width=3)
        d.line([(zx + 7 * zs, b - 36 * zs), (zx + 22 * zs, b - 40 * zs)], fill=(70, 120, 60), width=3)
        d.rectangle([zx - 6 * zs, b - 16 * zs, zx + 6 * zs, b], fill=(50, 44, 36))
    im.save(os.path.join(A, "stage_zombie.png"))


floor()
wall()
car()
barricade()
sky()
thumb()
print("tekstur peta zombie selesai")
