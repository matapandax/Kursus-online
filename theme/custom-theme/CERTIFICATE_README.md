# Kustomisasi Sertifikat — Catatan Deploy (theme `custom-theme`)

Dokumen ini mencatat semua perubahan untuk tampilan **sertifikat kustom (kartu ungu / Accredible-style)**
agar bisa di-deploy ulang ke instance Open edX lain.

Diverifikasi pada: Open edX **Quince** (native install), LMS gunicorn user = `www-data`.

---

## 1. Ringkasan mekanisme

- Sertifikat memakai **HTML certificate view lama** (`lms/djangoapps/certificates/views/webview.py`)
  yang merender `certificates/valid.html` → meng-`include` `certificates/_accomplishment-rendering.html`.
- Tampilan kustom dibuat lewat **comprehensive theming**, yaitu meng-*override* dua template itu
  di folder theme — **tanpa** mengubah kode `edx-platform`.
- **Tidak** memakai "Custom Certificate Templates" (DB) — fitur itu dimatikan.

---

## 2. File yang diubah (di dalam theme — ikut ter-copy)

Lokasi theme: `/edx/var/edxapp/themes/custom-theme/`

| File | Fungsi |
|---|---|
| `lms/templates/certificates/valid.html` | Layout **halaman** sertifikat (header, grid 2 kolom, sidebar "Verified credential" + share/print + About, footer). |
| `lms/templates/certificates/_accomplishment-rendering.html` | **Kartu** sertifikat (kurva ungu, judul, nama, course, tanda tangan, tanggal). Ini yang diedit untuk ubah desain kartu. |

> Folder `_backups/` di dalam theme berisi versi-versi lama (boleh dihapus, tidak dipakai runtime).

File theme lain yang juga ada (di luar lingkup sertifikat, dari pekerjaan sebelumnya):
`lms/templates/dashboard.html`, `lms/templates/courseware/course_about.html`, `cms/templates/widgets/footer.html`.

---

## 3. Konfigurasi / setting (DI LUAR theme — TIDAK ikut ter-copy, harus diset manual)

### a. Aktifkan theming (`/edx/etc/lms.yml`)
```yaml
ENABLE_COMPREHENSIVE_THEMING: true
DEFAULT_SITE_THEME: custom-theme
COMPREHENSIVE_THEME_DIRS:
  - /edx/var/edxapp/themes
```
Setelah ubah `lms.yml`: **restart LMS** (`sudo /edx/bin/supervisorctl restart lms`).

> Catatan: tanpa baris `SiteTheme` di DB pun tema tetap aktif karena `DEFAULT_SITE_THEME`
> (middleware `CurrentSiteThemeMiddleware` fallback ke setting ini).

### b. Pastikan HTML certificate aktif
- `FEATURES.CERTIFICATES_HTML_VIEW: true` (di `lms.yml`).
- Per course: di Studio → Settings → Certificates, sertifikat **Activate**.

### c. (Opsional) Logo & nama platform — Django Admin
`/admin/certificates/certificatehtmlviewconfiguration/`
- `logo_src` → logo (default Open edX: `/static/certificates/images/logo.png`).
  Catatan: logo yang benar-benar tampil sering di-override `branding_api.get_logo_url()`.
- `platform_name` → nama platform yang muncul di teks "Offered by … through {platform_name}".

### d. Yang TIDAK perlu/diaktifkan
- `FEATURES.CUSTOM_CERTIFICATE_TEMPLATES_ENABLED` = **false** (tidak dipakai).
- Tidak ada baris `CertificateTemplate` di DB (jumlah = 0).

---

## 4. Cara deploy ke instance Open edX lain

1. **Copy folder theme** ke server tujuan:
   ```
   /edx/var/edxapp/themes/custom-theme/   (minimal folder lms/templates/certificates/)
   ```
   Pastikan kepemilikan file bisa dibaca worker LMS (mis. `chown -R edxapp:edxapp`).
2. Set **`lms.yml`** seperti bagian 3a, lalu **restart LMS**.
3. (Opsional) Set logo & `platform_name` seperti 3c.
4. **Verifikasi** (bagian 5).

---

## 5. Cara verifikasi

Buka sebagai user staff (login):
```
http://<LMS>/certificates/course/<course_id>?preview=honor
```
Yang harus tampil: kartu **kurva ungu**, judul "CERTIFICATE OF ACHIEVEMENT", nama, course, tanggal.

Cek dari server (HTTP 200 + ada marker tema):
```
curl -s <preview_url> | grep -c "accpg"        # kurva ungu
curl -s <preview_url> | grep -c "acc-shell"    # layout halaman tema
```
> Render Mako di-cache di `/tmp/mako_lms`. Setelah edit template, **restart LMS** agar dimuat ulang,
> dan **hard-reload** browser (Ctrl+Shift+R) karena cache browser.

---

## 6. Variabel data yang dipakai kartu (`_accomplishment-rendering.html`)

| Tampil | Variabel konteks |
|---|---|
| Judul | `certificate_title` (fallback "Certificate of Achievement") |
| Nama penerima | `accomplishment_copy_name` |
| Nama course (asli) | `CourseOverview.get_from_id(course_id).display_name` |
| Judul sertifikat (opsional) | `accomplishment_copy_course_name` (course_title di config; ditambah hanya bila beda dari nama course) |
| Logo | `logo_src` (top), `organization_logo` (opsional) |
| Tanda tangan | loop `certificate_data.signatories` — **hanya** yang punya `signature_image_path` |
| Tanggal | `certificate_date_issued` |
| Nomor | `certificate_id_number` |
| "Offered by … through …" | `organization_long_name` / `platform_name` |

---

## 7. Cara ubah desain kartu

Edit **hanya** `lms/templates/certificates/_accomplishment-rendering.html`:
- **Warna ungu** → ubah gradien `linearGradient#accpg` (3 `stop-color`) + `.acc-cert-title` color (`#9c1f9c`) + `.acc-cert-course .org`.
- **Ukuran judul** → `.acc-cert-title { font-size: clamp(...) }` (saat ini `clamp(14px,2.3vw,24px)`, `white-space: nowrap`).
- **Teks/urutan** → bagian HTML di dalam `.acc-cert-body`.
Setelah edit: simpan → **restart LMS** → hard-reload.

> JANGAN buat versi ini sebagai DB "Custom Certificate Template" — di template DB, fungsi `_()` (gettext)
> tidak tersedia dan akan error. Di **theme** (file ini) `_()` aman karena ada import gettext.

---

## 8. Kompatibilitas versi

- Aman untuk **Quince** dan versi sekitarnya (Nutmeg/Olive/Palm/Redwood/Sumac) yang **masih** pakai
  HTML certificate lama + comprehensive theming.
- **Akan rusak** bila versi target memindah sertifikat ke **MFE/Credentials** (meninggalkan HTML cert lama).
- Titik paling rapuh = import `CourseOverview` (sudah dibungkus `try/except`, fallback aman).
- **Selalu tes** preview sertifikat setelah deploy di versi/instance baru.
