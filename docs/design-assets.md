# Diagram dan visual proposal

## Mengedit draw.io

Buka `diagrams/SENTINEL_Design.drawio` di diagrams.net melalui **File → Open From → Device**. Berkas berisi empat halaman:

| Halaman | Isi |
|---|---|
| 01_solution | Paket, buffer privat, shadow dan efek commit |
| 02_architecture | Modul, domain clock, batas kepercayaan dan status implementasi |
| 03_acceptance | Penerimaan, stall, pembatalan, scrub dan pemulihan |
| 04_budget | Batas desain FPGA; bukan hasil fitting |

Kotak, keputusan, panah dan sel tabel merupakan objek mxGraph yang dapat diedit. PNG pada proposal adalah pratinjau dari model yang sama. Warna biru/hijau menunjukkan RTL yang diuji; abu-abu menunjukkan rencana integrasi pada arsitektur. Parser dan core belum diuji bersama melalui serial.

## Membangun ulang visual dari source

Pengujian RTL hanya membutuhkan pustaka standar Python. Generator visual terpisah membutuhkan **Pillow**, serta Arial di Windows atau DejaVu Sans di Linux.

```bash
python3 -m pip install Pillow
python3 scripts/build_figures.py
```

Generator menulis empat PNG dan `.drawio`, serta `figures/06_trace.png` dan `visual_metrics.json`. Waveform dibentuk dari `evidence/trace.csv`; jumlah dan metrik dibaca dari `evidence/summary.json`. Tiga transaksi demo merupakan subset suite, bukan kasus tambahan. Budget ditulis sebagai batas rancangan karena Quartus dan board belum diuji.

Mengubah diagram langsung di editor tidak mengubah model Python. Simpan hasil edit dengan nama lain jika ingin mempertahankannya: menjalankan generator kembali menimpa file diagram dan PNG yang dihasilkan. Untuk perubahan permanen yang konsisten dengan proposal, ubah model di `scripts/build_figures.py`, jalankan generator, lalu periksa tata letak.

Sesudah seluruh suite berhasil, maintainer menjalankan `make capture` dan `make snapshot` untuk mengikat source, visual dan evidence dengan SHA-256. Pemeriksaan XML memastikan empat halaman, ID unik, geometry dan endpoint panah valid. Pembukaan melalui browser diagrams.net belum dapat diperiksa dalam sesi pengembangan ini karena browser automation tidak tersedia.
