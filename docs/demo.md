# Demo SENTINEL 3–5 menit

0:00–0:40 Jelaskan perintah konfigurasi/LED: plaintext dapat muncul sebelum tag; penerima harus mengendalikan efek transaksi. Tunjukkan diagram tiga tahap buffer privat, shadow, live register.

0:40–1:30 Jalankan `make snapshot` lalu `make demo`. Tag salah menghasilkan 16 word pada contoh consumer tanpa gate, sementara SENTINEL tidak commit. Paket sah dengan stall menghasilkan satu commit dan sequence 1. Replay memiliki tag sah tetapi commit 0 dan sequence tetap 1. Ketiga kasus adalah rekaman RTL, bukan demo board.

1:30–2:30 Tunjukkan `figures/06_trace.png` dan CSV. Soroti app_valid setelah autentikasi, app_ready rendah, commit tunggal dan last_seq berubah bersamaan. Tunjukkan satu kontrak word terakhir yang bersamaan dengan auth dan hasil parser terpotong.

2:30–3:30 Tunjukkan kampanye 10.697 transaksi, 10.290 parser frame, 7 kontrak, 2 mutant yang ditangkap, serta 1.024 sampel latensi. Jelaskan 2,80 µs sebagai start core ke commit dan 448 µs sebagai perhitungan wire.

3:30–4:30 Jelaskan target board, biaya wrapper dengan core baseline yang sama, dan batas yang masih harus diuji. Sesudah board lolos, ganti bagian rekaman dengan pengiriman sah/tamper/replay/reset nyata; simpan scoreboard dan SignalTap. Jangan mengganti label simulasi menjadi hasil hardware.
