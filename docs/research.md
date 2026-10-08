# Riset dan alasan keputusan desain

## Standar dan kontrak kriptografi

[NIST SP 800-232 final](https://csrc.nist.gov/pubs/sp/800/232/final), Agustus 2025, menetapkan Ascon-AEAD128. Gunakan versi standar dan KAT yang sesuai, karena varian submission lama memiliki perbedaan konstanta/bit order. Hasil KAT menyatakan kesesuaian implementasi pada vektor yang diuji, bukan sertifikasi NIST.

[RFC 5116](https://www.rfc-editor.org/rfc/rfc5116) memisahkan layanan AEAD dari keputusan anti-replay/access control. Seluruh header SENTINEL menjadi AD, nonce terikat sesi/sequence, dan keputusan replay baru menjadi state permanen saat commit. Pengirim harus menjaga keunikan nonce per kunci; counter wrap dilarang dan reaktivasi sesudah reset membutuhkan provisioning baru.

[Core Primas yang dipin](https://github.com/rprimas/ascon-verilog/tree/e1069549a1895f376391530a1842694ea8bb044b) memperingatkan bahwa plaintext dikeluarkan sebelum tag terverifikasi. Buffer privat menangani kebutuhan itu, sedangkan shadow aplikasi menangani atomicity sesudah data disetujui. Source vendor tidak dimodifikasi.

## Pembanding riset

[Kurian dan Chen 2025](https://doi.org/10.3390/electronics14132668) mengintegrasikan Ascon dan replay detection dengan Ascon-XOF128/Bloom filter pada Artix-7. SENTINEL memilih counter deterministik untuk satu sesi yang berurutan; tradeoff-nya adalah paket lama yang datang terlambat ditolak. Tidak diambil klaim keunggulan resource lintas device atau klaim keamanan kuantum dari judul artikel. Fokus evaluasi adalah hubungan autentikasi, release, dan efek aplikasi.

[Sledevič dan Andriukaitis 2026](https://doi.org/10.3390/electronics15091887), dengan [PDF institusi](https://epubl.ktu.edu/object/elaba%3A290383512/290383512.pdf), membahas proteksi pipeline FPGA-ARM. Relevansinya adalah keamanan datapath dan control path pada sistem tertanam; bukan bukti kinerja SENTINEL. Klaim penulis tentang limitasi platform tunggal mendukung pelaporan batas evaluasi kita.

## Konteks masalah dan baseline

[Laporan peneliti CVE-2026-27871](https://github.com/D-S-C-O-M-G-N-E-O/D-S-C-O-M-G-N-E-O/blob/main/CVE-2026-27871.md) menjelaskan replay perintah disarm yang menimbulkan efek walau sequence error dicatat. Kasus jaringan itu menjadi contoh perlunya mengikat pemeriksaan pada efek perintah; SENTINEL tidak diuji sebagai perbaikan TL280.

[TT07 CDC FIFO proyek 0036](https://github.com/Pa1mantri/tt07_cdc_fifo) mentransfer data 4 bit. Baseline memberi konsep perpindahan clock; framing byte dan token transaksi SENTINEL mempunyai kontrak berbeda. Kode FIFO TT07 tidak disalin. Integrasi board direncanakan memakai [DCFIFO vendor](https://docs.altera.com/r/docs/683522/current) dengan constraints dan reset review.

[Cyclone V Device Overview](https://docs.altera.com/r/docs/683694/current/cyclone-v-device-overview) dan [riwayat revisi](https://docs.altera.com/r/docs/683694/current/cyclone-v-device-overview/document-revision-history-for-cyclone-v-device-overview) menjadi denominator budget FPGA. Revisi 16 Maret 2026 mencatat A6 167.640 register. ALM, register dan M10K harus dilaporkan dari fitter pada konfigurasi sama untuk baseline dan wrapper.
