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

-- Checkout writes are server-validated; browser never supplies prices.
create or replace function public.ovth_place_order(
  p_name text, p_email text, p_phone text, p_address text,
  p_items jsonb, p_note text default ''
) returns text language plpgsql security definer
set search_path = '' as $$
declare
  item jsonb; qty int; total_qty int:=0; line_count int:=0;
  safe_items jsonb:='[]'::jsonb; new_no text;
begin
  if length(trim(coalesce(p_name,''))) not between 2 and 120
    or length(trim(coalesce(p_email,''))) not between 5 and 254
    or p_email !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    or length(trim(coalesce(p_phone,''))) not between 8 and 30
    or length(trim(coalesce(p_address,''))) not between 10 and 1000
    or length(coalesce(p_note,'')) > 1000
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) not between 1 and 6
  then raise exception 'Invalid checkout details'; end if;
  for item in select value from jsonb_array_elements(p_items) loop
    line_count:=line_count+1;
    if (item->>'edition') not in ('road','trail')
      or (item->>'color') not in ('Black','White')
      or (item->>'size') not in ('S','M','L','XL')
      or coalesce(item->>'qty','') !~ '^[0-9]{1,2}$'
    then raise exception 'Invalid product selection'; end if;
    qty:=(item->>'qty')::int;
    if qty < 1 or qty > 20 then raise exception 'Invalid quantity'; end if;
    total_qty:=total_qty+qty;
    safe_items:=safe_items || jsonb_build_array(jsonb_build_object(
      'edition',item->>'edition','code',case when item->>'edition'='road' then 'OVTH-01' else 'OVTH-02' end,
      'color',item->>'color','size',item->>'size','qty',qty,'unit_price_thb',590));
  end loop;
  if total_qty > 100 then raise exception 'Too many items'; end if;
  insert into public.ovth_orders(customer_name,customer_email,customer_phone,shipping_address,customer_note,items,subtotal_thb)
  values(trim(p_name),lower(trim(p_email)),trim(p_phone),trim(p_address),left(coalesce(p_note,''),1000),safe_items,total_qty*590)
  returning order_no into new_no;
  return new_no;
end $$;
revoke all on function public.ovth_place_order(text,text,text,text,jsonb,text) from public;
grant execute on function public.ovth_place_order(text,text,text,text,jsonb,text) to anon,authenticated;

-- IMPORTANT: anonymous checkout requires abuse protection before public launch.
-- Register owner in Supabase Auth, then run:
-- insert into public.ovth_owners(user_id) values ('YOUR_AUTH_USER_UUID');
-- NOTE: shipping is not priced yet; do not turn on checkout before pricing/stock/payment policy are finalized.
