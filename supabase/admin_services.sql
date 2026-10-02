-- Run once after cancellation.sql. Lets admins change service prices from the dashboard.
-- Existing appointments keep the price stored when they were booked.
alter table public.services add constraint services_price_max check (price <= 10000);
grant update (price) on public.services to authenticated;
create policy "Admins update service prices" on public.services
  for update to authenticated
  using (exists (select 1 from public.admins where user_id = (select auth.uid())))
  with check (exists (select 1 from public.admins where user_id = (select auth.uid())));
