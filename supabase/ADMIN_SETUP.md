# Setup akun admin PalugadaShop30

1. Buka Supabase Dashboard untuk proyek ini, lalu **Authentication → Users → Add user**.
2. Buat pengguna dengan email milik pemilik toko dan kata sandi kuat. Jangan mengaktifkan public sign-ups.
3. Setelah pengguna dibuat, buka SQL Editor dan jalankan SQL berikut dengan email yang sama (ganti alamat contoh):
```sql
insert into public.admin_users (user_id)
select id from auth.users
where lower(email) = lower('GANTI_DENGAN_EMAIL_ADMIN')
on conflict (user_id) do nothing;
```
4. Buka **Authentication → URL Configuration** dan tambahkan URL situs GitHub Pages ke Site URL / Redirect URLs bila diperlukan.
5. Setelah migrasi dijalankan, buka website dan tekan ikon roda gigi. Login memakai email/kata sandi tadi.
6. Jangan membuat akun admin tambahan kecuali memang diperlukan. Hanya user ID di `public.admin_users` yang punya izin tulis.

## Keamanan dan data lama

- `index.html` hanya berisi Supabase URL dan publishable key. Jangan pernah menambahkan secret key atau service-role key ke frontend.
- Migrasi SQL membuat katalog awal jika tabel kosong.
- Saat login pertama di browser yang masih memiliki data versi lama (`palu_products_v8`, `palu_cats_v8`, dan seterusnya), situs menawarkan impor. Menyetujui impor akan mengganti isi tabel produk/kategori bersama dengan data dari browser itu.
- Foto yang diunggah saat ini disimpan sebagai data URL di kolom `img` / `store_qris` database. Untuk koleksi foto besar, pindahkan ke Supabase Storage di langkah lanjutan.
- Auth menyimpan sesi login di browser sesuai mekanisme Supabase; data produk, kategori, tampilan, checkout, WhatsApp, dan QRIS disimpan di database bersama.
