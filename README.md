# Crisis Action DTP  v0.0.3.3  (Godot 4.3+)

Game FPS 3D ala Crisis Action: **Tim Merah vs Tim Biru**. Pilih tim & stage di menu,
kumpulkan **koin** dan **diamond**, tim yang lebih dulu mencapai target kill menang.
Semua tampilan dan animasi memakai gambar PNG di `assets/` (karakter per-frame, koin & diamond berputar,
senjata, HUD, tekstur, langit). Mau ganti tampilan? Timpa PNG dengan nama yang sama.

## Animasi 3D karakter dan VFX
- Bot memakai model procedural 3D ber-skeleton untuk pose jalan, diam, serang, loncat, skill, sakit, dan mati.
- Sprite PNG tetap dimuat sebagai fallback aset agar karakter lama tetap kompatibel dan seluruh peran mempertahankan bentuk visualnya.
- Efek GPUParticles3D ditambahkan untuk ledakan darah, percikan senjata, percikan tebasan, dan cincin efek skill.

## Yang baru di v0.0.3.0 (rumah detail, tangga halus, collision & optimasi)
- Rumah memiliki tekstur bata/plester triplanar, lis fondasi yang terputus di bukaan, lis sudut, kusen, jendela berpalang, pintu kayu berpanel, talang/tepian atap, dan ventilasi.
- Pintu depan memakai animasi buka-tutup otomatis saat pemain mendekat; badan rumah tetap statis.
- Rumah bertingkat memiliki lantai dua yang lebih luas, jalur tangga/ramp miring dengan sambungan bawah-atas yang rata, anak tangga visual, dan pegangan. Kemiringan lantai karakter disesuaikan agar tangga bisa dinaiki sambil berjalan tanpa menekan tombol lompat.
- Collision dipisahkan dari ornamen visual. Dinding, lantai atas, ramp, pegangan, pintu, perabot, batang pohon, mobil, dan tiang lampu memiliki collision; bukaan pintu/jendela tetap bisa dilalui.
- Perabot interior ditempatkan di sisi ruangan agar tidak menutup jalur pintu dan tangga.
- Optimasi: mesh rumah/kota digabung per material, pepohonan memakai MultiMesh, objek collision kota digabung pada satu badan statis, jumlah lampu dinamis dikurangi, dan mobil ditempatkan di sisi jalan.

## Cara pakai
1. Ekstrak zip, buka Godot -> Import -> pilih `project.godot`.
2. Tunggu import aset selesai, lalu tekan F5. Game dimulai dari menu.

## Yang baru di v0.0.2.8 (Kota Mati diperluas)
- Arena mode Zombie menjadi **250 × 250 unit**, sekitar **20× luas area** dibanding peta sebelumnya.
- Jaringan jalan kota, trotoar, rumah kecil, rumah keluarga, rumah dua lantai, apartemen/toko, pepohonan, dan mobil terbengkalai ditambahkan.
- Titik spawn manusia dan zombie diacak di jaringan jalan, dengan pemeriksaan jarak dari karakter lain dan bangunan.
- Bot memakai waypoint kota yang tersebar di seluruh arena; jarak pandang kamera ditambah untuk melihat area yang lebih luas.
- Gambar konsep rumah: `assets/zombie_houses_concept.png`; gambar konsep kota: `assets/zombie_city_concept.png`; pratinjau peta: `assets/map_kota_mati_overview.png`.
- Bangunan hunian mempunyai collision sehingga karakter tidak dapat berjalan menembus rumah.

## Yang baru di v0.0.2.7 (ronde, poin, animasi menang)
- Perbaikan error parse `hud.gd` (`STRETCH_KEEP_ASPECT_COVERED` di Godot 4.7).
- **Zombie yang mati tidak muncul lagi** (tidak ada respawn). Pemain yang tumbang juga gugur sampai ronde berikutnya.
- **Sistem ronde mode Zombie** (`scripts/main.gd`): manusia menang ronde kalau semua zombie mati atau waktu habis; zombie menang kalau semua manusia terinfeksi.
  HUD menampilkan **RONDE** dan **POIN MANUSIA - ZOMBIE**. Match selesai saat salah satu mencapai `ROUNDS_TO_WIN` (3). Ubah angka di atas `main.gd`.
- **Animasi menang** (`scripts/roundfx.gd`): ZOMBIE MENANG (layar merah, cakaran, darah menetes, tangan zombie naik, teks bergetar) dan
  MANUSIA MENANG (sinar emas berputar, konfeti, kilau, teks emas membesar), plus suara. Lama animasi: `ROUND_RESULT_TIME`.

## Yang baru di v0.0.2.6 (kartu pilih zombie, animasi loncat & skill, suara mati baru)
- **Layar pilih zombie gaya kartu** (`hud.gd`, `_build_choice`): 3 kartu potret (Biasa, Gendut, **Suster**), kartu terpilih berbingkai emas,
  tombol **"Memilih 00:09"** menghitung mundur; waktu habis = kartu yang disorot dipakai. Ketuk kartu untuk memilih, ketuk lagi / tombol = konfirmasi. PC: 1/2/3 + Enter.
- **Zombie Suster** (HP 1000): skill **Kabut virus** 8 detik - badan hampir tak terlihat, bot manusia kehilangan jejak (kecuali jarak <3 m), kabut hijau di layar.
- **Frame animasi baru**: `jump_0..1` (loncat) dan `skill_0..1` (pakai skill) untuk zombie, gendut, samurai; `char_suster/` set lengkap (diam, jalan, loncat, skill, serang, mati).
  Bot sekarang meloncat (saat macet / sesekali saat mengejar) dan memakai pose skill.
- **Tangan first-person sesuai karakter**: `zombie_hands_0..3`, `gendut_fists_0..3`, `suster_hands_0..3` (0/1 bergantian, 2 = loncat, 3 = skill).
- **Suara**: suara MATI khas yang baru untuk zombie biasa (2 variasi), gendut (2), suster, samurai; suara erangan/serang/kena/skill suster; suara loncat & mendarat.
- Generator: `tools/gen_chars.py` (gambar), `tools/gen_audio3.py` (suara). Frame idle/jalan/serang/mati lama zombie, gendut, samurai tidak ditimpa.

## Yang baru di v0.0.2.5 (layar mode, senjata baru, enhance, perlengkapan, animasi skill)
- **Layar pilih mode sebelum battle** (tab BATTLE -> `modes.tscn`, `scripts/modes.gd`), mengikuti screenshot: Ranking Match, Mode Tantangan (PVE),
  **Mode Zombie**, Mode Kreasi, Perang Meka, Arena Hiburan, **Latihan Solo**, Lobi Tempur. Mode yang belum ada terkunci per level
  (gembok + "LV.x TERBUKA"); Zombie, Latihan Solo, dan Lobi sudah bisa dipilih lalu masuk ke lobi. Ada gelembung petunjuk + panah naik-turun.
  Di lobi, tab BATTLE membawa kembali ke layar mode.
- **3 senjata baru** (satu per slot), data di `scripts/weapons.gd` (daftar `ALL`):
  - **M4A1 ELANG** (senjata utama, laju tembak tinggi, recoil rendah) - harga 3000 koin
  - **DESERT EAGLE** (pistol, damage 55, 7 peluru) - harga 2500 koin
  - **KARAMBIT** (pisau, damage 85, tebasan cepat) - harga 2000 koin
  - Gambar dibuat lewat `tools/gen_weapons.py`; suara Deagle `assets/sfx/deagle.wav`.
- **Layar ENHANCE** (tab ENHANCE -> `enhance.tscn`): daftar senjata per slot, **beli** senjata baru, **enhance** sampai Lv.8
  (biaya 400 x (level+1) koin; tombol 1 KLIK menaikkan sampai koin habis/maks), **pasang** senjata, statistik sebelum >> sesudah.
  Tiap level: damage +5%, akurasi +4% (sebaran peluru berkurang), stabilitas +5% (recoil berkurang). Efek: gambar membesar, kilat, percikan, suara.
- **Layar PERLENGKAPAN** (tile EQUIP di beranda -> `inventory.tscn`): panel statistik senjata (damage, kecepatan, akurasi, stabilitas, mobilitas,
  jangkauan, magasin, reload + bonus enhance), kotak senjata milik, tombol PASANG dan ENHANCE.
- Senjata yang **terpasang + level enhance** dipakai di battle (HUD slot, tembakan, recoil). Mobilitas senjata memengaruhi kecepatan lari sedikit.
- **Animasi & suara skill** (satu gambar utama + kode, tanpa banyak frame) di `scripts/skillfx.gd`:
  - Lari zombie: garis kecepatan, tepi merah, FOV melebar, tangan bergetar + memerah, suara desis.
  - Perisai zombie gendut: bingkai biru berdenyut, cincin gelombang, tangan berkilau biru, suara dengung nyala + pecah saat habis.
  - Tebasan berat samurai: busur tebasan menyala, kamera bergetar, ayunan katana besar, suara tebasan + hantaman.
  - Tombol skill: cincin cooldown, denyut saat siap, kilau + bunyi "ting" ketika siap lagi. Bot juga punya suara + percikan saat memakai skill.
- Koin awal 5000 untuk save baru (beli & enhance). Save lama tetap memakai koin yang ada.
- Suara baru dibuat lewat `tools/gen_audio2.py`.

## Yang baru di v0.0.2.4 (suara, musik, animasi, peta Zombie)
- **Peta khusus mode Zombie: "Kota Mati"** (jalan malam, langit merah berbulan, kabut merah, bangkai mobil, barikade, tembok berpapan).
  Mode Pelatihan tetap memakai Stage 1/2. Data peta: `_stage_zombie()` di `scripts/stages.gd`; tekstur `assets/z_*.png`.
- **Suara khas tiap karakter** (`scripts/fx.gd`, tabel `VOICES`; file di `assets/sfx/`):
  - Zombie biasa: erangan serak melengking (3 variasi), geraman + cakaran, jeritan kena, erangan mati + gorgle.
  - Zombie gendut: erangan berat dan dalam, pukulan (ayunan + hantaman), dengusan kena, mati panjang + tubuh jatuh, **langkah berat** (bot).
  - Samurai: desing tebasan cepat, **kiai + tebasan berat**, dengusan kena, mati + pedang jatuh, **cabut pedang** saat berubah jadi samurai.
  - Umum: jeritan manusia terinfeksi, peluru kena daging, benturan cakar/tebasan, raungan Induk Zombie di awal ronde.
  - Induk Zombie bersuara lebih berat. Zombie bot mengerang sendiri tiap beberapa detik (lebih sering kalau melihat musuh).
- **Musik latar**: mode Zombie = drone gelap + denyut jantung + jeritan biola jauh; saat dua manusia terakhir jadi Samurai musiknya
  berganti taiko + shakuhachi + koto.
- **Animasi**: zombie berjalan terhuyung dan menerjang saat menyerang, gendut menghentak dan lamban, samurai menerjang saat menebas;
  skill Lari = tubuh memerah, skill Perisai gendut = menyala biru; first-person: cakar mengais terus, kepalan gendut mengayun berat,
  katana bergoyang napas. Gambar tangan disinkronkan lagi tiap ganti peran (cakar/kepalan/katana).
- Semua suara & tekstur baru dibuat lewat skrip: `tools/gen_audio.py` dan `tools/gen_zmap.py` (jalankan ulang untuk menimpa/ubah).

## Yang baru di v0.0.2.3
- **Lobi (tab BATTLE)**: tombol HUNT diganti pilihan mode **PELATIHAN / ZOMBIE / CLASSIC**.
  - **Pelatihan** = lawan bot, tampilan Tim Merah vs Tim Biru (seperti sebelumnya).
  - **Zombie** = tampilan slot bukan tim merah/biru, 14 pemain (kamu + bot).
  - **Classic** = online, belum hadir (muncul pesan).
- **Mode Zombie** (angka di `scripts/player.gd`, `scripts/bot.gd`, `scripts/main.gd`):
  - Ada 1 **Induk Zombie** (zombie pertama, pelari, HP 2.300; induk gendut HP 3.400). Manusia yang kena serang zombie langsung diminta memilih jadi:
    **Zombie pelari** (HP 850, lari cepat 7 detik) atau **Zombie gendut** (HP 1.250, perisai kurangi damage 95% selama 9 detik).
  - Cooldown semua skill zombie 40 detik. Damage semua zombie 300, kecepatan serang normal.
  - Kalau tersisa 2 manusia, keduanya jadi **Samurai** (HP 5.200): serangan cepat 250 damage, serangan lambat 800 damage (tombol/ E).
  - Damage senjata manusia x10 di mode ini (karena HP zombie ribuan); headshot +85%.
  - Manusia menang kalau ada yang bertahan 3 menit; zombie menang kalau semua terinfeksi.
- **Karakter baru**: sprite Zombie (pelari), Zombie gendut, dan Samurai (folder `assets/char_zombie`, `char_gendut`, `char_samurai`).
  Tampilan first-person: Zombie pelari = dua tangan bercakar yang terus bergerak (ketuk serang = mencakar), Zombie gendut = dua kepalan yang bergerak (serang = memukul lurus), Samurai = katana (serang = menebas).
- **Tombol senjata tunggal**: senjata utama, pistol, pisau digabung jadi satu tombol di bawah layar; ketuk untuk memilih (seperti referensi).
- **Koin & diamond dihapus dari gameplay** (tidak ada di map, tidak jatuh dari musuh, tidak tampil di HUD). Hadiah akhir match masih ada.
- Kontrol PC tambahan: **E** = skill zombie / serangan berat samurai.

## Yang baru di v0.0.2.1
- **Beranda baru (tab MAIN)** mengikuti screenshot: karakter di kiri, tombol ROLE / RANKED MATCH / EQUIP / CREATION / TASK / RANK di kanan, QUICK BATTLE, tab MAIN-BATTLE-ENHANCE-SOCIAL, tombol SHOP.
  - ROLE = pilih Tim Merah/Biru. EQUIP = lihat 3 senjata. QUICK BATTLE = langsung main.
  - Menu yang belum ada fiturnya (Ranked, Creation, Task, Rank, Event, Shop, dll.) menampilkan pesan "segera hadir".
- **Lobi baru (tab BATTLE)**: slot pemain Tim Merah | Tim Biru (EMPTY / terisi), pilih peta dengan panah, jumlah pemain, **Aim Assist OFF/ON**, Quick Chat, HUNT (mengisi slot dengan bot), Start, Invite Player. Kolom Password hanya tampilan.
- **3 senjata**: slot 1 senjata utama (otomatis, 30 peluru), slot 2 pistol (satu-satu, 12 peluru), slot 3 pisau (jarak dekat, 60 damage, tanpa peluru).
  - PC: tombol 1 / 2 / 3, Q senjata sebelumnya, scroll mouse. HP: ketuk kotak senjata di bawah layar.
  - HUD: kotak slot senjata di bawah layar (seperti screenshot), sisa peluru tiap senjata, tangan memegang senjata sesuai pilihan.
  - Data senjata (damage, peluru, kecepatan, jarak) ada di `scripts/weapons.gd`.
- Aim Assist memutar bidikan sedikit ke musuh yang hampir di tengah layar. Pilihannya tersimpan.
- Setelah match, tombol MENU kembali ke lobi.
- Aset baru: `pistol_fp.png`, `knife_fp.png`, `icon_rifle.png`, `icon_pistol.png`, `icon_knife.png`.

## Yang baru di v0.0.2
- **Menu**: pilih Tim Merah atau Tim Biru (bisa dua-duanya, ganti kapan saja), pilih Stage, lihat koin & diamond.
- **Karakter beda**: merah (seragam merah, ikat kepala kuning, kacamata oranye) dan biru (seragam biru, ikat kepala putih, kacamata cyan).
  Gambar di `assets/char_red/` dan `assets/char_blue/`.
- **Mode tim**: kamu + bot teman lawan bot tim musuh. Bot saling tembak, tidak ada friendly fire untuk pemain.
- **Stage 1 - Gudang Siang** (4 vs 4, target 20 kill) dan **Stage 2 - Kota Malam** (5 vs 5, target 30 kill, malam + lampu jalan, bot lebih jago).
- **Koin & diamond**: ada di map (muncul lagi setelah beberapa detik) dan jatuh dari bot musuh yang kamu kalahkan.
  Animasi putar/kilau pakai gambar `coin_0..7.png` dan `diamond_0..7.png`.
- **Reward akhir match**: Stage 1 menang +50 koin +5 diamond (kalah +10 koin); Stage 2 menang +90 koin +10 diamond (kalah +20 koin +1 diamond).
- Progres (koin, diamond, tim, stage) tersimpan otomatis di `user://crisis_action_save.json`.
- **Stage 3, 4, 5**: tampil terkunci, **terbuka di v0.0.3**.

## Kontrol PC
WASD gerak, mouse bidik, klik kiri tembak, Spasi lompat, R reload, 1/2/3 ganti senjata, Q senjata sebelumnya, Esc lepas mouse (lalu bisa klik tombol MENU).

## Kontrol HP
Joystick kiri gerak, geser layar kanan untuk bidik, tombol merah tembak (sambil geser untuk bidik), tombol reload dan lompat.

## Isi
- scripts/game.gd    : autoload `Game` - koin, diamond, tim, stage, simpan/muat, versi
- scripts/stages.gd  : data tiap stage (layout, tekstur, spawn tim, koin, reward)
- scripts/menu.gd    : beranda (ROLE, EQUIP, Quick Battle, tab)
- scripts/lobby.gd   : lobi (slot pemain, peta, Aim Assist, Start)
- scripts/weapons.gd : data semua senjata, level enhance, statistik
- scripts/modes.gd, enhance.gd, inventory.gd, skillfx.gd : layar mode, Enhance, Perlengkapan, efek skill
- scripts/ui.gd, topbar.gd, tabbar.gd : komponen UI bersama
- scripts/main.gd    : bangun arena dari data stage, spawn bot dua tim, skor tim, loot, reward
- scripts/player.gd  : gerak, tembak (raycast, headshot x2), reload, darah
- scripts/bot.gd     : AI bot (cari musuh terdekat, patroli, memburu, strafe, menembak), animasi sprite
- scripts/pickup.gd  : koin & diamond beranimasi gambar
- scripts/hud.gd     : HUD gambar, skor tim, koin/diamond, senjata first-person, kontrol sentuh, hasil
- scripts/fx.gd      : suara & efek partikel gambar

## Atur permainan
- Target kill, jumlah bot per tim, kesulitan, reward: di `scripts/stages.gd` (`target`, `team_size`, `skill`, `win_coins`, ...).
- Nilai koin/diamond drop: konstanta di atas `scripts/main.gd`.
- Buka stage baru: tambah fungsi `_stageN()` di `stages.gd`, daftarkan di `get_stage()`, lalu naikkan `MAX_STAGE_OPEN` di `scripts/game.gd`
  (v0.0.3: ubah `2` menjadi `5`, dan ganti nama/thumbnail di `STAGE_INFO`).

## Export Android
Project -> Export -> Android (orientasi sudah landscape, renderer Compatibility).
