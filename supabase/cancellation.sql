-- Run once after booking.sql. Customer self-cancellation via secret link and
-- e-mail notifications (Edge Function "notify", called asynchronously via pg_net).
create extension if not exists pg_net with schema extensions;

alter table public.appointments add column cancel_token uuid not null default gen_random_uuid() unique;
alter table public.appointments add column cancelled_at timestamptz;
alter table public.appointments add column cancelled_by text check (cancelled_by in ('customer', 'admin'));

drop function public.book_appointment(text, date, text, text, text, text);
create function public.book_appointment(
  p_service_id text, p_day date, p_time text,
  p_name text, p_email text, p_phone text)
returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  s public.services;
  st timestamptz;
  token uuid;
begin
  select * into s from public.services where id = p_service_id;
  if not found then raise exception 'invalid_service'; end if;
  p_name := btrim(coalesce(p_name, '')); p_email := lower(btrim(coalesce(p_email, ''))); p_phone := btrim(coalesce(p_phone, ''));
  if length(p_name) not between 1 and 100 or p_name ~ '[[:cntrl:]]' or p_phone ~ '[[:cntrl:]]'
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
    returning cancel_token into token;
  exception when exclusion_violation then
    raise exception 'slot_taken';
  end;
  return token;  -- the customer's private cancel token, also sent by e-mail
end $$;

-- What the cancel page may show: no name, e-mail or phone.
create function public.get_booking(p_token uuid)
returns table (service text, starts_at timestamptz, duration_minutes integer, status text, cancellable boolean)
language sql stable security definer set search_path = '' as $$
  select a.service, a.starts_at, a.duration_minutes, a.status,
         a.status = 'confirmed' and a.starts_at - now() >= interval '24 hours'
  from public.appointments a where a.cancel_token = p_token
$$;

create function public.cancel_appointment(p_token uuid)
returns void
language plpgsql volatile security definer set search_path = '' as $$
declare a public.appointments;
begin
  select * into a from public.appointments where cancel_token = p_token for update;
  if not found then raise exception 'not_found'; end if;
  if a.status = 'cancelled' then raise exception 'already_cancelled'; end if;
  if a.status <> 'confirmed' or a.starts_at - now() < interval '24 hours' then raise exception 'too_late'; end if;
  update public.appointments set status = 'cancelled', cancelled_at = now(), cancelled_by = 'customer' where id = a.id;
end $$;

-- Admin cancellations from the dashboard are recorded the same way.
create function public.stamp_cancellation() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    new.cancelled_at := coalesce(new.cancelled_at, now());
    new.cancelled_by := coalesce(new.cancelled_by, 'admin');
  end if;
  return new;
end $$;
create trigger appointments_stamp_cancellation before update of status on public.appointments
  for each row execute function public.stamp_cancellation();

-- Sends booking/cancellation events to the Edge Function. The shared secret lives in Vault.
create function public.notify_appointment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  kind text;
  secret text;
begin
  if tg_op = 'INSERT' then kind := 'booked';
  elsif new.status = 'cancelled' and old.status <> 'cancelled' then kind := 'cancelled';
  else return new; end if;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'notify_webhook_secret';
  if secret is null then return new; end if;
  perform net.http_post(
    url := 'https://hieefplluyxsaivfeszj.supabase.co/functions/v1/notify',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', secret),
    body := jsonb_build_object('type', kind, 'client_name', new.client_name, 'client_email', new.client_email,
      'client_phone', new.client_phone, 'service', new.service, 'starts_at', new.starts_at,
      'duration_minutes', new.duration_minutes, 'price', new.price,
      'cancel_token', new.cancel_token, 'cancelled_by', new.cancelled_by));
  return new;
end $$;
create trigger appointments_notify after insert or update of status on public.appointments
  for each row execute function public.notify_appointment();

revoke all on function public.book_appointment(text, date, text, text, text, text) from public, anon, authenticated;
revoke all on function public.get_booking(uuid) from public, anon, authenticated;
revoke all on function public.cancel_appointment(uuid) from public, anon, authenticated;
revoke all on function public.stamp_cancellation() from public, anon, authenticated;
revoke all on function public.notify_appointment() from public, anon, authenticated;
grant execute on function public.book_appointment(text, date, text, text, text, text) to anon, authenticated;
grant execute on function public.get_booking(uuid) to anon, authenticated;
grant execute on function public.cancel_appointment(uuid) to anon, authenticated;
