create table if not exists gift_catalog (
  id bigserial primary key,
  code varchar(40) not null unique,
  name varchar(80) not null,
  emoji varchar(16) not null,
  coin_cost integer not null check (coin_cost > 0),
  gift_xp integer not null check (gift_xp >= 0),
  generosity_xp integer not null check (generosity_xp >= 0),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into gift_catalog(code,name,emoji,coin_cost,gift_xp,generosity_xp,sort_order,active)
values
  ('rose','Gül','🌹',5,5,5,10,true),
  ('coffee','Kahve','☕',12,12,12,20,true),
  ('heart','Kalp','💚',20,20,20,30,true),
  ('sparkle','Işıltı','✨',35,35,35,40,true),
  ('balloon','Balon','🎈',50,50,50,50,true),
  ('rocket','Roket','🚀',75,75,75,60,true),
  ('diamond','Elmas','💎',120,120,120,70,true),
  ('crown','Taç','👑',200,200,200,80,true)
on conflict(code) do update set
  name=excluded.name,
  emoji=excluded.emoji,
  coin_cost=excluded.coin_cost,
  gift_xp=excluded.gift_xp,
  generosity_xp=excluded.generosity_xp,
  sort_order=excluded.sort_order,
  active=excluded.active,
  updated_at=now();

create table if not exists user_wallets (
  user_id bigint primary key references users(id) on delete cascade,
  coin_balance integer not null default 0 check (coin_balance >= 0),
  gift_xp integer not null default 0 check (gift_xp >= 0),
  generosity_xp integer not null default 0 check (generosity_xp >= 0),
  gifts_received integer not null default 0 check (gifts_received >= 0),
  gifts_sent integer not null default 0 check (gifts_sent >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into user_wallets(user_id)
select id from users
on conflict(user_id) do nothing;

create table if not exists room_gifts (
  id bigserial primary key,
  room_id bigint not null references rooms(id) on delete cascade,
  sender_user_id bigint not null references users(id) on delete cascade,
  recipient_user_id bigint not null references users(id) on delete cascade,
  gift_id bigint not null references gift_catalog(id),
  coin_cost integer not null check (coin_cost > 0),
  gift_xp integer not null check (gift_xp >= 0),
  generosity_xp integer not null check (generosity_xp >= 0),
  client_gift_id varchar(96) not null,
  created_at timestamptz not null default now(),
  check (sender_user_id <> recipient_user_id),
  unique(sender_user_id, client_gift_id)
);

create index if not exists room_gifts_room_id_idx
  on room_gifts(room_id,id);
create index if not exists room_gifts_recipient_idx
  on room_gifts(recipient_user_id,created_at desc);
create index if not exists room_gifts_sender_idx
  on room_gifts(sender_user_id,created_at desc);

create table if not exists wallet_transactions (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  transaction_type varchar(40) not null,
  coin_delta integer not null,
  balance_after integer not null check (balance_after >= 0),
  reference_type varchar(40),
  reference_id bigint,
  idempotency_key varchar(128),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists wallet_transactions_idempotency_idx
  on wallet_transactions(user_id,idempotency_key)
  where idempotency_key is not null;
create index if not exists wallet_transactions_user_created_idx
  on wallet_transactions(user_id,created_at desc);
