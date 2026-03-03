# Langkah-langkah Mengaktifkan Google Calendar Export

Agar fitur **Export ke Google Calendar** berjalan, Anda harus mengonfigurasi **OAuth 2.0** di Google Cloud Console dan menambahkan **Client ID** untuk Android dan/atau iOS.

---

## 1. Buat Project di Google Cloud Console

1. Buka [Google Cloud Console](https://console.cloud.google.com/).
2. Klik **Select a project** di atas, lalu **New Project**.
3. Isi nama project (misalnya `AI Schedule Generator`) dan klik **Create**.

---

## 2. Aktifkan Google Calendar API

1. Di menu kiri: **APIs & Services** > **Library**.
2. Cari **Google Calendar API**.
3. Klik **Enable**.

---

## 3. Konfigurasi OAuth Consent Screen

1. **APIs & Services** > **OAuth consent screen**.
2. Pilih **External** (kecuali Anda pakai Google Workspace, bisa pilih Internal).
3. Isi:
   - **App name**: AI Schedule Generator (atau nama lain).
   - **User support email**: email Anda.
   - **Developer contact**: email Anda.
4. Klik **Save and Continue**.
5. Di **Scopes**: klik **Add or Remove Scopes**, cari dan tambah:
   - `https://www.googleapis.com/auth/calendar`  
     (lihat dan mengelola semua calendar).
6. **Save and Continue** sampai selesai.

---

## 4. Buat OAuth 2.0 Client ID (Credentials)

1. **APIs & Services** > **Credentials**.
2. **Create Credentials** > **OAuth client ID**.
3. **Application type**:
   - Untuk Android: pilih **Android**.
   - Untuk iOS: pilih **iOS**.
   - Untuk testing di Chrome/Web: pilih **Web application** (opsional).
4. Isi sesuai platform (lihat di bawah), lalu **Create**.

---

## 5a. Android: Client ID & SHA-1

1. Di **Create OAuth client ID** pilih **Android**.
2. **Name**: misalnya `AI Schedule Generator Android`.
3. **Package name**: harus sama dengan aplikasi Flutter Anda.  
   Cek di `android/app/build.gradle` (atau `build.gradle.kts`), bagian `applicationId`.  
   Contoh: `com.example.ai_schedule_generator`.
4. **SHA-1 certificate fingerprint**:
   - **Debug (development)**  
     Di folder project, jalankan:
     ```bash
     # Windows (PowerShell)
     cd android
     ./gradlew signingReport
     ```
     Atau dengan keytool (Java sudah terpasang):
     ```bash
     keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
     Salin nilai **SHA1** (tanpa titik dua atau format lain, biasanya sudah ditampilkan).
   - **Release**  
     Gunakan keystore release Anda dan jalankan `keytool` dengan keystore tersebut.
5. Paste **SHA1** ke kolom **SHA-1 certificate fingerprint** di Console, lalu **Create**.
6. Simpan **Client ID** (opsional untuk Flutter; Android pakai `google-services.json` jika Anda menambahkannya).

**Penting:** Di Flutter Android, `google_sign_in` memakai SHA-1 dari debug/release keystore. Pastikan SHA-1 yang Anda daftarkan sama dengan yang dipakai saat build.

---

## 5b. iOS: Client ID & URL Scheme

1. Di **Create OAuth client ID** pilih **iOS**.
2. **Name**: misalnya `AI Schedule Generator iOS`.
3. **Bundle ID**: sama dengan di Xcode/Flutter.  
   Cek di `ios/Runner.xcodeproj` atau `ios/Runner/Info.plist`.  
   Contoh: `com.example.aiScheduleGenerator`.
4. **Create**.
5. Di project Flutter, tambah URL scheme untuk reverse client ID:
   - Buka `ios/Runner/Info.plist`.
   - Tambah key `CFBundleURLTypes` (jika belum ada) dengan item yang berisi:
     - `CFBundleURLSchemes`: array berisi **reversed client ID**.  
       Contoh: jika Client ID Anda `123456-xxx.apps.googleusercontent.com`, maka scheme-nya: `com.googleusercontent.apps.123456-xxx`.
   - Contoh isi:
     ```xml
     <key>CFBundleURLTypes</key>
     <array>
       <dict>
         <key>CFBundleTypeRole</key>
         <string>Editor</string>
         <key>CFBundleURLSchemes</key>
         <array>
           <string>com.googleusercontent.apps.CLIENT_ID_ANDA</string>
         </array>
       </dict>
     </array>
     ```
   - Ganti `CLIENT_ID_ANDA` dengan reversed client ID (format: `com.googleusercontent.apps.XXXXX`).

**Catatan:** Untuk `google_sign_in` di iOS, kadang perlu juga menambahkan file `GoogleService-Info.plist` dari Firebase (jika Anda pakai Firebase). Untuk hanya Google Sign-In + Calendar, konfigurasi OAuth Client ID + URL scheme di atas biasanya cukup.

---

## 6. (Opsional) Web Client untuk Development

Jika Anda menjalankan di **Chrome (web)**:

1. Buat **OAuth client ID** dengan tipe **Web application**.
2. Tambahkan **Authorized redirect URIs** (misalnya `http://localhost:PORT` dari Flutter web).
3. Simpan **Client ID**; untuk web kadang perlu set di kode (lihat dokumentasi `google_sign_in` web).

---

## 7. Cek di Aplikasi

1. Jalankan `flutter pub get`.
2. Build dan jalankan di **device fisik** atau **emulator dengan Google Play** (Android).  
   Emulator tanpa Google Play / belum login Google mungkin tidak bisa sign-in.
3. Di app: buat jadwal dengan AI, lalu di halaman hasil pilih **Export ke Google Calendar**.
4. Saat diminta, **login dengan akun Google** dan beri izin akses Calendar.
5. Buka aplikasi **Google Calendar** (web atau mobile) dan pastikan event sudah muncul.

---

## Troubleshooting

| Masalah | Kemungkinan solusi |
|--------|---------------------|
| "Login dibatalkan" | User menutup dialog login; coba lagi dan selesaikan login. |
| "Akses ditolak" / 403 | Pastikan Calendar API sudah di-enable; OAuth consent screen sudah ada scope Calendar; pakai akun yang sama dengan yang di Console. |
| "Tidak bisa mendapatkan akses" | Sign out dari Google di device, lalu coba Export lagi (login ulang). |
| Android: Sign-in gagal tanpa pesan jelas | Pastikan SHA-1 di Console sama dengan `signingReport` / debug.keystore. |
| iOS: Redirect tidak jalan | Cek `CFBundleURLSchemes` di Info.plist dan reversed client ID. |

---

## Ringkasan Checklist

- [v] Project Google Cloud dibuat
- [v] Google Calendar API di-enable
- [v] OAuth consent screen dikonfigurasi (termasuk scope Calendar)
- [v] OAuth Client ID untuk Android dibuat (dengan package name + SHA-1)
- [v] OAuth Client ID untuk iOS dibuat (dengan bundle ID) + URL scheme di Info.plist
- [v] `flutter pub get` sudah dijalankan
- [-] Tes Export di device/emulator dengan akun Google

Setelah semua langkah ini, tombol **Export ke Google Calendar** di halaman hasil jadwal akan login ke Google dan menambahkan event ke calendar **primary** akun yang login.
