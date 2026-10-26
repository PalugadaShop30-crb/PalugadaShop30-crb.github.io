-- PalugadaShop30 shared catalog + admin-only writes
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- Then create the admin Auth user and follow supabase/ADMIN_SETUP.md.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id text primary key,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id text primary key,
  title text not null check (length(trim(title)) > 0),
  cat text null references public.categories(id) on delete set null,
  price numeric(12,2) not null check (price >= 0),
  orig numeric(12,2) null check (orig is null or orig >= 0),
  badge text null,
  description text not null default '',
  img text not null default '',
  addons jsonb not null default '[]'::jsonb check (jsonb_typeof(addons) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_settings (
  id integer primary key check (id = 1),
  ui_settings jsonb not null default '{}'::jsonb,
  checkout_fields jsonb not null default '[]'::jsonb,
  store_wa text not null default '6281234567890',
  store_qris text not null default '',
  updated_at timestamptz not null default now()
);

create or replace function public.is_palugada_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users au
    where au.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_palugada_admin() from public;
grant execute on function public.is_palugada_admin() to anon, authenticated;

alter table public.admin_users enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.store_settings enable row level security;

drop policy if exists "admin can read own admin record" on public.admin_users;
create policy "admin can read own admin record"
  on public.admin_users for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "public can read categories" on public.categories;
create policy "public can read categories"
  on public.categories for select to anon, authenticated using (true);
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories"
  on public.categories for all to authenticated
  using ((select public.is_palugada_admin()))
  with check ((select public.is_palugada_admin()));

drop policy if exists "public can read products" on public.products;
create policy "public can read products"
  on public.products for select to anon, authenticated using (true);
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products"
  on public.products for all to authenticated
  using ((select public.is_palugada_admin()))
  with check ((select public.is_palugada_admin()));

drop policy if exists "public can read store settings" on public.store_settings;
create policy "public can read store settings"
  on public.store_settings for select to anon, authenticated using (true);
drop policy if exists "admins manage store settings" on public.store_settings;
create policy "admins manage store settings"
  on public.store_settings for all to authenticated
  using ((select public.is_palugada_admin()))
  with check ((select public.is_palugada_admin()));

revoke all on public.admin_users from anon;
grant select on public.admin_users to authenticated;
grant select on public.categories, public.products, public.store_settings to anon, authenticated;
grant insert, update, delete on public.categories, public.products, public.store_settings to authenticated;

-- Seed default catalog only when tables are empty.
insert into public.categories (id, name) values
  ('kopken', 'Kopi Kenangan'),
  ('fnb', 'FnB & Roti'),
  ('digital', 'Voucher Lainnya')
on conflict (id) do nothing;

insert into public.products (id, title, cat, price, orig, badge, description, img, addons) values
  ('1', 'Voucher Kopi Kenangan Rp 25.000', 'kopken', 19500, 25000, 'DISKON', 'Kupon saldo tanpa minimal belanja.', 'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=400', '[]'::jsonb),
  ('2', '1x Kopi Kenangan Mantan (Large)', 'kopken', 18500, 24000, 'FAVORIT', 'Redeem 1 Cup Mantan Large.', 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=400', '[{"name":"Boba","price":3000},{"name":"Extra Shot Espresso","price":4000},{"name":"Less Sugar","price":0}]'::jsonb),
  ('3', 'Voucher Fore Coffee 1 Cup', 'fnb', 21000, 29000, null, 'Bebas pilih varian minuman.', 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=400', '[]'::jsonb)
on conflict (id) do nothing;

insert into public.store_settings (id, ui_settings, checkout_fields, store_wa, store_qris)
values (
  1,
  jsonb_build_object(
    'promoLeft', $$<span class='badge-promo'>PROMO</span> Diskon Spesial Hari Ini! Kode: <strong>HEMAT</strong>$$,
    'promoRight', '24 Jam',
    'headerName', 'Palugada Shop30',
    'headerSub', 'Spesialis Voucher Digital',
    'heroBgImg', '',
    'heroTitle', 'Selamat Datang di<br><span>Palugada Shop30</span>',
    'heroSub', 'Pusat belanja digital paling murah dan aman. Diproses kilat ke WhatsApp!',
    'guaranteeTitle', 'Garansi Pelayanan:',
    'guaranteeList', E'✅ Proses Otomatis & Cepat\n✅ Harga Termurah se-Indonesia\n✅ Mendukung Pembayaran QRIS',
    'waBtn', 'Kirim Bukti Bayar ke WA'
  ),
  jsonb_build_array(
    jsonb_build_object('id','f_nama','label','Nama Lengkap','type','text','req',true),
    jsonb_build_object('id','f_wa','label','Nomor WhatsApp Aktif','type','number','req',true),
    jsonb_build_object('id','f_catatan','label','Catatan / Request','type','text','req',false)
  ),
  '6281234567890',
  'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=Belum-Ada-QRIS'
)
on conflict (id) do nothing;

-- Enable live shared updates for the browser client, if not already enabled.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products'
  ) then alter publication supabase_realtime add table public.products; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'categories'
  ) then alter publication supabase_realtime add table public.categories; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'store_settings'
  ) then alter publication supabase_realtime add table public.store_settings; end if;
end $$;
