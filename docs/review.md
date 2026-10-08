# Audit rancangan dan perubahan 8 Oktober 2026

| Temuan | Perubahan | Bukti dan batas |
|---|---|---|
| Judul Inggris kurang menjelaskan efek aplikasi | Judul Indonesia menonjolkan penerimaan dan commit atomik | Konsisten dengan RTL dan kategori Secure Communication |
| Bukti 2.531 kasus dominan KAT dan satu basis mutasi | 10.697 transaksi dengan 9 basis mutasi, semua ukuran dan posisi release | CSV/manifest; KAT tetap core saja |
| Live state hanya banyak diperiksa di akhir | Monitor per edge di testbench | Perubahan tanpa commit memicu fatal |
| Final word bersamaan auth ditolak karena count lama | Guard memakai collected_after_beat dan beat_ok | Kontrak final_word_and_auth_same_edge |
| Packing intermediate beat ambigu | Hanya beat terakhir boleh kurang dari 4 byte | Kontrak partial_intermediate_word ditolak |
| Timeout masih rencana | Watchdog parser/guard; commit ditutup pada edge timeout | Default 100.000 siklus; test dipercepat 512/1.024/64 siklus |
| Parser belum RTL | Parser byte/token, frozen descriptor, reject reason | 10.290 kasus terpisah |
| p99 belum punya dataset khusus | 1.024 sampel 64 byte acak tanpa stall | Median/p99 140 siklus simulasi |
| Assertion sendiri belum diuji | Dua mutant acceptance harus gagal | mutation_results.json |
| Diagram hanya gambar jadi | draw.io 4 halaman dan PNG yang konsisten | Konsep solusi, arsitektur, alur penerimaan, budget |
| Paket belum dapat dipelihara otomatis | Make targets, CI, hash evidence/source, panduan demo | [CI lulus setelah publikasi](https://github.com/Fijarsatria/SENTINEL/actions/runs/37769224704) |

## Pekerjaan berikut yang menentukan kesiapan board

1. Adapter parser-ke-core mengikat header, byte order, panjang beat dan hasil auth pada satu transaksi.
2. SPI sampler dengan CS termination, FIFO vendor, overflow sticky dan flush dua domain.
3. MMIO write-only staging key dan aktivasi sesi lengkap; tidak ada jalur live-payload dari HPS.
4. Joint reset dengan kedua clock tersedia, flush, scrub dan provisioning baru sebelum READY.
5. Quartus/TimeQuest, baseline core yang sama, SignalTap dan daya; seluruh hasil aktual disimpan.

Kenaikan kompleksitas ditujukan pada kasus kegagalan dan kontrak yang dapat diuji. Board, ketahanan fisik dan side-channel masih membutuhkan bukti tersendiri. Audit ini tidak menyatakan probabilitas memenangkan kompetisi.
