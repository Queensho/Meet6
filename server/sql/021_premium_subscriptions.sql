create table if not exists user_subscriptions (
  user_id bigint primary key references users(id) on delete cascade,
  provider varchar(32) not null default 'revenuecat',
  entitlement_id varchar(120) not null default 'premium',
  product_id varchar(200),
  store varchar(40),
  environment varchar(24),
  status varchar(24) not null default 'inactive'
    check (status in ('inactive','active','grace_period','billing_issue','expired')),
  expires_at timestamptz,
  will_renew boolean not null default false,
  original_transaction_id varchar(255),
  last_event_id varchar(255),
  last_event_at timestamptz,
  provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_subscriptions_active_idx
  on user_subscriptions(status, expires_at desc);

create table if not exists subscription_events (
  id bigserial primary key,
  provider varchar(32) not null default 'revenuecat',
  provider_event_id varchar(255) not null,
  user_id bigint references users(id) on delete set null,
  event_type varchar(80) not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  unique(provider, provider_event_id)
);

create index if not exists subscription_events_user_idx
  on subscription_events(user_id, created_at desc);

alter table matchmaking_queue
  add column if not exists priority_tier smallint not null default 0;

alter table matchmaking_queue
  add column if not exists requested_room_duration_minutes smallint not null default 15;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'matchmaking_queue_duration_check'
  ) then
    alter table matchmaking_queue
      add constraint matchmaking_queue_duration_check
      check (requested_room_duration_minutes in (15, 30));
  end if;
end $$;

create index if not exists matchmaking_queue_priority_idx
  on matchmaking_queue(requested_room_duration_minutes, priority_tier desc, joined_at asc);

alter table rooms
  add column if not exists room_duration_minutes smallint not null default 15;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'rooms_duration_check'
  ) then
    alter table rooms
      add constraint rooms_duration_check
      check (room_duration_minutes between 1 and 60);
  end if;
end $$;

update rooms
set room_duration_minutes = greatest(
  1,
  least(
    60,
    round(extract(epoch from (ends_at - started_at)) / 60.0)::int
  )
)
where room_duration_minutes = 15
  and ends_at > started_at;
