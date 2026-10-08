# Verifikasi dan reproduksi

## Suite dan asal angka

Hasil baru memakai Verilator 5.048, seed 20261008, clock 20 ns. Suite lama 2.531 transaksi / 260 commit disimpan di `evidence/baseline`. Jalankan `make verify` untuk kompilasi ulang, `make mutations` untuk uji assertion, dan `make snapshot` untuk integritas paket. `make capture` hanya dipakai maintainer setelah seluruh suite dan mutasi berhasil; ia menyalin bukti dan memperbarui hash source.

| Grup core/guard/app | Jumlah |
|---|---:|
| KAT resmi, core saja | 1.089 |
| Paket sah acak awal | 256 |
| Kampanye latensi 64 byte tanpa stall | 1.024 |
| Seluruh ukuran 1–64 byte × stall 0/1/8/100 siklus | 256 |
| Mutasi setiap bit pada 9 transaksi dasar | 7.936 |
| Kasus terarah awal | 34 |
| Stall pada 16 posisi beat × 3 durasi | 48 |
| Abort pada setiap posisi release | 16 |
| Reset pada setiap posisi release | 16 |
| Batas sequence dan replay | 12 |
| Timeout release pada 10 ukuran | 10 |
| Total | 10.697 |

1.593 commit sesuai harapan. Assertion memeriksa plaintext terhadap oracle C, live payload dan count commit, kestabilan ready/valid, tidak ada pelepasan sebelum autentikasi, serta penghapusan 16 word privat. Monitor mengamati kedua sisi setiap edge (termasuk pembaruan nonblocking): perubahan live state membutuhkan commit, dan perubahan `last_seq` membutuhkan commit atau reset/provisioning.

Parser diuji terpisah pada 10.290 kasus: 10.000 frame dengan pola valid/truncation/extra byte/length 0/length 65/abort/overflow/timeout, 113 posisi abort, 113 posisi reset, dan 64 ukuran sah. Hasil: 1.314 diterima, 8.976 ditolak/dibatalkan/direset. Kasus reset tidak disebut penolakan kriptografi. Pengujian menyandingkan descriptor dengan byte input, memeriksa reason reject, dan mencoba menimpa descriptor saat consumer stall.

Tujuh kontrak guard menguji final-word+auth pada edge yang sama, packing normal, partial intermediate word, zero-byte beat, extra word, collect timeout dan release timeout. Kontrak itu memakai stimulus langsung tanpa core kriptografi.

`make mutations` menonaktifkan pemeriksaan autentikasi atau sequence dalam salinan sementara. Kedua mutant harus gagal dengan assertion yang relevan. Kegagalan tersebut adalah hasil yang diharapkan, bukan dua transaksi sah tambahan. Source aktif tidak diubah.

## Latensi dan statistik

| Pengukuran simulasi | Sampel | Median | p99 |
|---|---:|---:|---:|
| Start core ke commit, 64 byte, tanpa stall | 1.024 | 140 siklus / 2,80 µs | 140 siklus / 2,80 µs |
| Start core ke commit, semua paket diterima dengan ragam ukuran/stall | 1.593 | 140 siklus / 2,80 µs | 240 siklus / 4,80 µs |
| Start core ke autentikasi, demo 64 byte AD 32 byte | 1 | 124 siklus / 2,48 µs | Tidak digunakan sebagai estimasi distribusi |

p99 memakai nearest rank `ceil(0.99*n)`. Event awal adalah peluncuran mode core/frame_start testbench; event akhir adalah edge penerimaan beat terakhir (`app_commit`). Tidak ada byte serial pada pengukuran ini. Dataset semua ukuran/stall tidak disamakan dengan kampanye 64 byte tanpa stall.

Pada board, ukur SCLK byte pertama, byte terakhir, commit dan READY kembali dengan definisi sama antar baseline. Untuk 64 byte: 112 byte wire pada 2 Mbit/s = 448 µs; target last-byte-to-commit ≤20 µs, first-byte-to-commit ≤500 µs. Wire efficiency 64/112=57,14%; batas goodput wire ideal 1,143 Mbit/s. Goodput nyata dihitung `8*jumlah_payload_tercommit/waktu_pengamatan`, termasuk jeda transaksi dan scrub; belum diukur.

## File bukti

`summary.json` dan `case_manifest.json` menjelaskan jumlah dan kategori; `results.csv` menyimpan outcome dan timing tiap kasus; `trace.csv`/`sentinel.vcd` menyimpan tiga demo; `parser_results.csv`, `guard_contract_results.csv`, log dan `mutation_results.json` menyimpan suite tambahan. `SHA256SUMS.txt` mengikat evidence, RTL, generator dan testbench.

## Gate integrasi berikutnya

SPI/CDC dan adapter belum diuji bersama core. Tambahkan scoreboard byte serial hingga commit, clock ratio 1:4–4:1 dan fase acak, full/empty/overflow, CS terpotong, clock berhenti, serta reset dua domain. Gunakan IP vendor dan constraint yang sesuai Cyclone V; simulasi tidak membuktikan metastabilitas aman. Setelah board tersedia: ≥1.000 paket sah dan ≥1.000 serangan/replay, TimeQuest, resource, daya idle/aktif dan baseline core yang sama. Laporan menyebut hasil aktual dan kasus yang belum selesai.
