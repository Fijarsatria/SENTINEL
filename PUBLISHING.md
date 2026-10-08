# Publikasi dan pemeriksaan remote

Target: https://github.com/Fijarsatria/SENTINEL. Source, diagram, dokumentasi dan evidence dipublikasikan setelah semua suite lulus; keberhasilan pengiriman harus dibuktikan dengan hash branch remote, bukan hanya commit lokal.

```bash
make verify
make mutations
make snapshot
git status --short
git push -u origin main
git ls-remote origin refs/heads/main
```

Tidak memakai force push. Jika remote telah berubah, fetch dan integrasikan terlebih dahulu. CI mengompilasi suite pada Ubuntu 24.04, menjalankan mutation check dan memeriksa snapshot. Hasil runtime CI disimpan sebagai artifact; versi simulator dapat berbeda dari bukti lokal dan dicatat di log. Data pribadi sampul proposal tidak dikirim ke repository source.
