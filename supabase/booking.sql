-- Run once after schema.sql. Public booking with server-side availability
-- and a database-level guarantee against double booking (single chair).
create extension if not exists btree_gist with schema extensions;

create table public.services (
  id text primary key,
  name text not null unique,
  duration_minutes integer not null check (duration_minutes > 0),
  price numeric(10,2) not null check (price >= 0)
);
alter table public.services enable row level security;
revoke all on public.services from anon, authenticated;
grant select on public.services to anon, authenticated;
create policy "Anyone can read services" on public.services for select to anon, authenticated using (true);
insert into public.services values
  ('manicure', 'Manicure & gellak', 60, 35),
  ('haircut', 'Knippen & stylen', 45, 30),
  ('brows', 'Wenkbrauwen modelleren', 20, 15);

alter table public.appointments add column ends_at timestamptz not null;
alter table public.appointments add column created_at timestamptz not null default now();

create function public.set_appointment_end() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.ends_at := new.starts_at + make_interval(mins => new.duration_minutes);
  return new;
end $$;
create trigger appointments_set_end before insert or update of starts_at, duration_minutes, ends_at
  on public.appointments for each row execute function public.set_appointment_end();

-- No two active appointments may overlap, even under concurrent requests.
alter table public.appointments add constraint appointments_no_overlap
  exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&) where (status <> 'cancelled');

-- Opening hours: starts on the hour 09:00-17:00, must end by 18:00 (Europe/Amsterdam), up to 90 days ahead.
create function public.get_available_slots(p_day date, p_service_id text)
returns table (slot text)
language sql stable security definer set search_path = '' as $$
  select to_char(make_time(h, 0, 0), 'HH24:MI')
  from public.services s,
       generate_series(9, 17) h,
       lateral (select (p_day + make_time(h, 0, 0)) at time zone 'Europe/Amsterdam' as st) t
  where s.id = p_service_id
    and p_day <= (now() at time zone 'Europe/Amsterdam')::date + 90
    and t.st > now()
    and make_interval(hours => h, mins => s.duration_minutes) <= interval '18 hours'
    and not exists (
      select 1 from public.appointments a
      where a.status <> 'cancelled'
        and tstzrange(a.starts_at, a.ends_at, '[)')
            && tstzrange(t.st, t.st + make_interval(mins => s.duration_minutes), '[)'))
  order by h
$$;

create function public.book_appointment(
  p_service_id text, p_day date, p_time text,
  p_name text, p_email text, p_phone text)
returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  s public.services;
  st timestamptz;
  new_id uuid;
begin
  select * into s from public.services where id = p_service_id;
  if not found then raise exception 'invalid_service'; end if;
  p_name := btrim(coalesce(p_name, '')); p_email := lower(btrim(coalesce(p_email, ''))); p_phone := btrim(coalesce(p_phone, ''));
  if length(p_name) not between 1 and 100
     or length(p_email) > 200 or p_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$'
     or length(p_phone) > 30 or length(regexp_replace(p_phone, '\D', '', 'g')) < 9 then
    raise exception 'invalid_details';
  end if;
  if p_time is null or p_time !~ '^\d{2}:00$' or p_time not in (select slot from public.get_available_slots(p_day, p_service_id)) then
    raise exception 'slot_taken';
  end if;
  if (select count(*) from public.appointments
      where client_email = p_email and status <> 'cancelled' and starts_at > now()) >= 3 then
    raise exception 'too_many_bookings';
  end if;
  st := (p_day + p_time::time) at time zone 'Europe/Amsterdam';
  begin
    insert into public.appointments (client_name, client_email, client_phone, service, starts_at, duration_minutes, price)
    values (p_name, p_email, p_phone, s.name, st, s.duration_minutes, s.price)
    returning id into new_id;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;
  return new_id;
end $$;

revoke all on function public.get_available_slots(date, text) from public, anon, authenticated;
revoke all on function public.book_appointment(text, date, text, text, text, text) from public, anon, authenticated;
revoke all on function public.set_appointment_end() from public, anon, authenticated;
grant execute on function public.get_available_slots(date, text) to anon, authenticated;
grant execute on function public.book_appointment(text, date, text, text, text, text) to anon, authenticated;
