# Temu Penyuluh

Web app SvelteKit untuk petani dan penyuluh. SvelteKit menangani UI dan halaman, Supabase menyediakan Google/email authentication, PostgreSQL, RLS, dan penyimpanan foto privat. Deployment disiapkan untuk Vercel.

## Jalankan lokal

1. Pasang Node.js 22 atau yang lebih baru.
2. Dari folder proyek, jalankan `npm install`.
3. Salin `.env.example` menjadi `.env` lalu isi URL proyek Supabase dan publishable key.
4. Jalankan `npm run dev` dan buka alamat lokal yang ditampilkan.

Tanpa konfigurasi Supabase, tombol **Coba prototipe** tetap membuka dashboard demo petani, penyuluh, dan admin. Data demo berjalan di browser. Setelah Supabase dikonfigurasi, lahan, jadwal, dan permintaan konsultasi pada pengguna yang masuk disimpan ke database.

## Sambungkan Supabase

1. Buat proyek di Supabase.
2. Buka **SQL Editor**, jalankan seluruh isi `supabase/schema.sql`.
3. Salin **Project URL** dan **Publishable key** dari halaman Connect/API Keys ke `.env`:

   ```env
   PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
   PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
   ```

   Publishable key memang digunakan di browser; jangan pernah memasukkan `service_role` key ke variabel `PUBLIC_` atau commit rahasia ke Git.

4. Di Supabase, buka **Authentication → Providers → Google**, aktifkan Google, dan masukkan OAuth Client ID dan Client Secret dari Google Cloud. Tambahkan callback URI Supabase yang ditampilkan di konfigurasi Google provider sebagai **Authorized redirect URI** Google.
5. Di **Authentication → URL Configuration**, isi Site URL dengan domain lokal saat pengembangan, misalnya `http://localhost:5173`. Tambahkan URL lokal dan URL Vercel production/preview yang digunakan ke daftar **Redirect URLs**. Aplikasi mengarahkan OAuth ke `/auth/callback`.
6. Buat pengguna admin/officer dari Authentication, lalu atur `profiles.role` melalui SQL Editor setelah akun profil terbentuk. Jangan memberi role istimewa dari browser. Profil penyuluh harus ditinjau dan diverifikasi oleh admin.

Google OAuth memerlukan kredensial dari pemilik proyek Google Cloud dan Supabase; aplikasi sudah menyiapkan tombol OAuth, callback PKCE berbasis cookie, serta alur email tanpa password (magic link).

## Deploy ke Vercel

1. Push folder proyek ini ke repository Git.
2. Import repository tersebut di Vercel. Framework akan terdeteksi sebagai SvelteKit; adapter Vercel sudah diatur di `svelte.config.js`.
3. Di **Project Settings → Environment Variables**, tambahkan `PUBLIC_SUPABASE_URL` dan `PUBLIC_SUPABASE_PUBLISHABLE_KEY` untuk Production, Preview, dan Development.
4. Deploy. Build command standar SvelteKit (`npm run build`) dan output ditangani adapter Vercel.
5. Tambahkan domain deployment Vercel ke Supabase **Site URL/Redirect URLs** dan Authorized JavaScript origins di Google Cloud OAuth. Redeploy setelah mengubah variabel environment.

## Halaman dan alur yang tersedia

- Landing page dan login Google/email.
- Dashboard petani, daftar/detail/tambah lahan, foto lahan, kalender serta tambah/tandai kegiatan.
- Daftar penyuluh, pembuatan konsultasi, ruang chat, dan lampiran foto tanaman.
- Belajar Tani, artikel, informasi awal hama/penyakit dengan penjelasan bahwa ini bukan diagnosis, notifikasi, dan profil.
- Dashboard penyuluh, daftar permintaan dan jadwal kunjungan (data demo).
- Dashboard admin/verifikasi akun (tampilan demo; role istimewa hanya dapat ditetapkan melalui database).

## Batasan prototype saat ini

- Data cuaca, hama, percakapan awal, penyuluh, artikel dan kalender demo adalah data contoh; koneksi ke API cuaca, layanan peta, notifikasi push/email terjadwal, realtime chat, dan data katalog penyuluh belum ditautkan.
- Supabase schema memberi batas akses RLS per pengguna untuk lahan, jadwal, konsultasi, pesan, notifikasi, artikel, laporan, serta foto. Role `officer` dan `admin` wajib diberikan oleh pengelola database setelah verifikasi.
- Upload foto tersimpan privat di Supabase Storage dan dibatasi 5 MB pada antarmuka. Untuk produksi, tambahkan moderation, signed URL yang kedaluwarsa, kebijakan retensi, dan pemantauan error.
