# Integrasi DE10-Nano

Target: Cyclone V SE 5CSEBA6U23I7, clk_sys 50 MHz, clk_io 25 MHz, SPI mode 0 hingga 2 Mbit/s. Folder ini adalah panduan integrasi, bukan project Quartus yang telah fitted. Pinout mengikuti revisi board yang benar dan baru ditetapkan setelah board tersedia.

Urutan bring-up: LED heartbeat → reset dan clocks → FIFO flush → transaksi byte parser → adapter Ascon → shadow/commit LED → provisioning MMIO → campaign serangan. Gunakan `docs/board-integration.md` untuk peta register dan reset. Jangan menulis `.sof` palsu atau mengklaim timing closure dari simulasi 20 ns.

Baseline resource: core Ascon saja dan subsistem lengkap pada part, tool version, clocks, seed fitter dan stimulus identik. Laporkan delta ALM/register/M10K, slack, Fmax dan power idle/aktif. Budget awal ≤6.000 ALM, ≤5.000 register, ≤6 M10K, 0 DSP, ≤1 FPGA PLL. 3.200 bit buffer logis tidak otomatis memerlukan satu M10K; packing dan port menentukan bank fisik.
