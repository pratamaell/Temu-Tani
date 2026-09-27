-- Temu Penyuluh: jalankan seluruh file ini di Supabase SQL Editor.
-- Role 'officer' dan 'admin' hanya boleh diberikan oleh pengelola terpercaya.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Petani',
  role text not null default 'farmer' check (role in ('farmer','officer','admin')),
  requested_role text not null default 'farmer' check (requested_role in ('farmer','officer')),
  region text default '',
  village text default '',
  district text default '',
  province text default '',
  specialty text default '',
  commodities text[] not null default '{}',
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1), 'Petani'))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.current_profile_role()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid()
$$;

create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  crop text not null,
  area_m2 numeric not null check (area_m2 > 0),
  location text not null default '',
  village text default '',
  district text default '',
  province text default '',
  land_type text default '',
  planted_at date,
  estimated_harvest date,
  growth_stage text default 'Baru ditanam',
  status text default 'Tumbuh dengan baik',
  progress integer not null default 5 check (progress between 0 and 100),
  image_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  field_id uuid references public.fields(id) on delete set null,
  field_name text default '',
  title text not null,
  kind text not null default 'Lainnya',
  scheduled_at timestamptz not null,
  notes text default '',
  completed boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.consultations (
  id uuid primary key default gen_random_uuid(),
  farmer_id uuid not null references public.profiles(id) on delete cascade,
  officer_id uuid references public.profiles(id) on delete set null,
  topic text not null default 'Konsultasi pertanian',
  description text default '',
  status text not null default 'pending' check (status in ('pending','active','resolved','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  attachment_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles(id) on delete set null,
  title text not null,
  category text not null default 'Budidaya',
  body text not null default '',
  cover_path text,
  read_minutes integer not null default 4,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.pest_reports (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  field_id uuid references public.fields(id) on delete set null,
  name text not null,
  symptoms text not null default '',
  image_path text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists fields_owner_id_idx on public.fields(owner_id);
create index if not exists activities_owner_date_idx on public.activities(owner_id, scheduled_at);
create index if not exists consultations_farmer_created_idx on public.consultations(farmer_id, created_at desc);
create index if not exists messages_consultation_created_idx on public.messages(consultation_id, created_at);
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.fields enable row level security;
alter table public.activities enable row level security;
alter table public.consultations enable row level security;
alter table public.messages enable row level security;
alter table public.articles enable row level security;
alter table public.notifications enable row level security;
alter table public.pest_reports enable row level security;

drop policy if exists "profiles read authenticated" on public.profiles;
create policy "profiles read authenticated" on public.profiles for select to authenticated using (true);
drop policy if exists "profile owner update safe fields" on public.profiles;
create policy "profile owner update safe fields" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid() and role = public.current_profile_role());
-- Users may update requested_role, contact/location and specialties. They cannot grant their own verified, officer, or admin status.
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and (new.role is distinct from old.role or new.verified is distinct from old.verified) then
    raise exception 'Role and verification status can only be changed by a trusted administrator.';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_profile_privileges_trigger on public.profiles;
create trigger protect_profile_privileges_trigger before update on public.profiles for each row execute procedure public.protect_profile_privileges();

drop policy if exists "field owner all" on public.fields;
create policy "field owner all" on public.fields for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "activity owner all" on public.activities;
create policy "activity owner all" on public.activities for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid() and (field_id is null or exists (select 1 from public.fields f where f.id = field_id and f.owner_id = auth.uid())));

drop policy if exists "consultation participants read" on public.consultations;
create policy "consultation participants read" on public.consultations for select to authenticated using (farmer_id = auth.uid() or officer_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));
drop policy if exists "farmer create consultation" on public.consultations;
create policy "farmer create consultation" on public.consultations for insert to authenticated with check (farmer_id = auth.uid() and officer_id is null and status = 'pending');
drop policy if exists "consultation participants update" on public.consultations;
create policy "consultation participants update" on public.consultations for update to authenticated using (farmer_id = auth.uid() or officer_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')) with check (farmer_id = auth.uid() or officer_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists "message participants read" on public.messages;
create policy "message participants read" on public.messages for select to authenticated using (exists (select 1 from public.consultations c where c.id = consultation_id and (c.farmer_id = auth.uid() or c.officer_id = auth.uid())));
drop policy if exists "message participant send" on public.messages;
create policy "message participant send" on public.messages for insert to authenticated with check (sender_id = auth.uid() and exists (select 1 from public.consultations c where c.id = consultation_id and c.status in ('active','pending') and (c.farmer_id = auth.uid() or c.officer_id = auth.uid())));

drop policy if exists "published articles read" on public.articles;
create policy "published articles read" on public.articles for select to anon, authenticated using (published or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('officer','admin')));
drop policy if exists "officer manage articles" on public.articles;
create policy "officer manage articles" on public.articles for all to authenticated using (author_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')) with check ((author_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'officer')) or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists "notification owner all" on public.notifications;
create policy "notification owner all" on public.notifications for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "pest report owner and officer" on public.pest_reports;
create policy "pest report owner and officer" on public.pest_reports for all to authenticated using (owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('officer','admin'))) with check (owner_id = auth.uid() or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('officer','admin')));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('field-photos','field-photos',false,5242880,array['image/jpeg','image/png','image/webp']),
       ('consultation-photos','consultation-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "field photo owner upload" on storage.objects;
create policy "field photo owner upload" on storage.objects for insert to authenticated with check (bucket_id = 'field-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "field photo owner read" on storage.objects;
create policy "field photo owner read" on storage.objects for select to authenticated using (bucket_id = 'field-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "field photo owner delete" on storage.objects;
create policy "field photo owner delete" on storage.objects for delete to authenticated using (bucket_id = 'field-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "consultation photo participant upload" on storage.objects;
create policy "consultation photo participant upload" on storage.objects for insert to authenticated with check (bucket_id = 'consultation-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "consultation photo participant read" on storage.objects;
create policy "consultation photo participant read" on storage.objects for select to authenticated using (bucket_id = 'consultation-photos' and ((storage.foldername(name))[1] = auth.uid()::text or exists (select 1 from public.consultations c where c.farmer_id::text = (storage.foldername(name))[1] and c.officer_id = auth.uid())));

grant usage on schema public to anon, authenticated;
grant select on public.articles to anon, authenticated;
grant select, insert, update, delete on public.profiles, public.fields, public.activities, public.consultations, public.messages, public.articles, public.notifications, public.pest_reports to authenticated;
