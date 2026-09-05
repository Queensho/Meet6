create table if not exists coin_products (
  id bigserial primary key,
  product_id varchar(120) not null unique,
  coin_amount integer not null check (coin_amount > 0),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into coin_products(product_id,coin_amount,sort_order,active)
values
  ('meet6_coins_100',100,10,true),
  ('meet6_coins_300',300,20,true),
  ('meet6_coins_700',700,30,true),
  ('meet6_coins_1500',1500,40,true)
on conflict(product_id) do update set
  coin_amount=excluded.coin_amount,
  sort_order=excluded.sort_order,
  active=excluded.active,
  updated_at=now();

create table if not exists coin_purchase_receipts (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  provider varchar(30) not null default 'revenuecat',
  product_id varchar(120) not null,
  provider_transaction_id varchar(220) not null,
  store varchar(40),
  purchased_at timestamptz,
  coin_amount integer not null check (coin_amount > 0),
  provider_payload jsonb not null default '{}'::jsonb,
  credited_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique(provider,provider_transaction_id)
);

create index if not exists coin_purchase_receipts_user_created_idx
  on coin_purchase_receipts(user_id,created_at desc);
