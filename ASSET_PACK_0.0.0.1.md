# Asset pack 0.0.0.1 — format karakter untuk Godot

Paket ini menetapkan **format teknis** untuk frame animasi karakter 2D di proyek Godot:

- PNG RGBA transparan, kanvas seragam **256 × 256 px**.
- Penamaan frame: `idle_0.png`, `walk_0.png`, `shoot_0.png`, `die_0.png`, `jump_0.png`, dan `skill_0.png` (akhiran angka mengikuti jumlah frame tiap animasi).
- Simpan frame di folder `assets/char_nama/`. Gunakan kanvas dan titik dasar yang sama untuk seluruh frame satu karakter agar animasi tidak bergeser saat diputar.
- File PNG dapat langsung disalin ke folder `assets/` proyek Godot. Buka proyek atau pilih **Project → Reload Current Project** agar Godot mengimpor aset. File `.import` dan cache `.godot/` dibuat oleh Godot; keduanya tidak perlu disertakan dalam paket.

## Validasi sebelum impor

Dari direktori root proyek, jalankan:

```bash
python3 -m pip install pillow
python3 tools/validate_character_assets.py
```

Validator memeriksa frame bernomor di semua `assets/char_*/`: file PNG terbaca, ukuran seragam 256 × 256, mode RGBA, dan gambar tidak sepenuhnya transparan. Untuk ukuran kanvas lain, gunakan `--size N`. Validasi ini menjamin konsistensi **format dan dimensi**, bukan penilaian artistik otomatis atas kemiripan setiap detail visual.

## Membuat ulang gambar

Generator karakter yang sudah ada membuat frame baru dengan gaya visual dan kanvas proyek:

```bash
python3 -m pip install pillow numpy
python3 tools/gen_chars.py
python3 tools/validate_character_assets.py
```

Periksa hasil gambar sebelum menimpa atau menambahkan aset baru; generator sengaja mempertahankan sejumlah frame karakter lama. Jangan mengganti versi aplikasi yang sudah ada: `0.0.0.1` di sini adalah versi **spesifikasi paket aset**, sementara versi proyek Godot tetap mengikuti `project.godot`.
