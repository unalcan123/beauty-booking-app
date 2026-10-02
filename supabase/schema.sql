-- Run once in a new Supabase project's SQL editor.
create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;
grant select on public.admins to authenticated;
create policy "Admins see own membership" on public.admins
  for select to authenticated using (user_id = (select auth.uid()));

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  client_name text not null,
  client_email text not null,
  client_phone text not null,
  service text not null,
  starts_at timestamptz not null,
  duration_minutes integer not null check (duration_minutes > 0),
  price numeric(10,2) not null check (price >= 0),
  status text not null default 'confirmed' check (status in ('confirmed','completed','cancelled'))
);
alter table public.appointments enable row level security;
revoke all on public.appointments from anon, authenticated;
grant select, insert, update, delete on public.appointments to authenticated;
create policy "Only admins manage appointments" on public.appointments
  for all to authenticated
  using (exists (select 1 from public.admins where user_id = (select auth.uid())))
  with check (exists (select 1 from public.admins where user_id = (select auth.uid())));
-- Create the owner in Authentication > Users, then run with their UUID:
-- insert into public.admins(user_id) values ('OWNER-USER-UUID');
-- Public booking (availability + no double booking): run supabase/booking.sql next.