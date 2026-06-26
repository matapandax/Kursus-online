# Halaman pembayaran sertifikat (demo QRIS)

Dipasang di: `/edx/var/edxapp/payment/index.html`

## nginx (vhost LMS, /etc/nginx/sites-available/lms) — tambah di dalam server block:
```
location /pay/ {
    alias /edx/var/edxapp/payment/;
    index index.html;
}
```
(JANGAN simpan file backup .bak di dalam sites-enabled/ — nginx ikut membacanya.)

## Site Configuration (LMS)
Set `CERT_PAYMENT_URL = /pay/index.html` pada SiteConfiguration aktif.
Tombol "Klaim Sertifikat" di dashboard akan mengarah ke sana.

## Yang perlu DIGANTI sebelum produksi
- Gambar QR -> QRIS statis merchant Anda (atau integrasi gateway).
- Nominal (saat ini Rp 750.000).
- Nomor WhatsApp konfirmasi (saat ini contoh 6281234567890).
