-- OVERTHILL orders. Run in the existing Supabase project's SQL editor.
-- Configure the owner's auth user ID after signing up; never publish service-role keys.
create table if not exists public.ovth_owners (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.ovth_owners enable row level security;
create policy "owner sees own membership" on public.ovth_owners for select to authenticated using (user_id = (select auth.uid()));

create table if not exists public.ovth_orders (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null default ('OTH-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  created_at timestamptz not null default now(),
  customer_name text not null check(length(customer_name) between 2 and 120),
  customer_email text not null check(length(customer_email) between 5 and 254),
  customer_phone text not null check(length(customer_phone) between 8 and 30),
  shipping_address text not null check(length(shipping_address) between 10 and 1000),
  customer_note text not null default '',
  channel text not null default 'website' check(channel in ('website','instagram')),
  items jsonb not null check(jsonb_typeof(items)='array'),
  subtotal_thb integer not null check(subtotal_thb >= 0),
  shipping_thb integer not null default 0 check(shipping_thb >= 0),
  payment_status text not null default 'awaiting_payment' check(payment_status in ('awaiting_payment','submitted','verified','rejected')),
  fulfillment_status text not null default 'new' check(fulfillment_status in ('new','preparing','shipped','delivered','cancelled')),
  courier text,
  tracking_number text,
  tracking_mode text not null default 'manual' check(tracking_mode in ('manual','etrackings')),
  shipped_at timestamptz,
  delivered_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.ovth_orders enable row level security;
create policy "owner can read orders" on public.ovth_orders for select to authenticated using (exists(select 1 from public.ovth_owners where user_id=(select auth.uid())));
create policy "owner can update orders" on public.ovth_orders for update to authenticated using (exists(select 1 from public.ovth_owners where user_id=(select auth.uid()))) with check (exists(select 1 from public.ovth_owners where user_id=(select auth.uid())));
create policy "owner can create manual orders" on public.ovth_orders for insert to authenticated with check (channel='instagram' and exists(select 1 from public.ovth_owners where user_id=(select auth.uid())));

-- This migration is deployed to the existing Wealth PWA Supabase project.
-- Owner membership is assigned separately to the verified existing auth user.
grant usage on schema public to authenticated;
grant select on public.ovth_owners to authenticated;
grant select,insert,update on public.ovth_orders to authenticated;
-- Public checkout is disabled until final price, shipping, payment, and abuse prevention are ready.
-- No anonymous checkout RPC has been deployed.
