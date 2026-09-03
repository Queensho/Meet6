create table if not exists moderation_warnings (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  admin_user_id bigint references users(id) on delete set null,
  reason varchar(500) not null,
  created_at timestamptz not null default now()
);

create index if not exists moderation_warnings_user_idx
  on moderation_warnings(user_id, created_at desc);

create table if not exists user_bans (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  admin_user_id bigint references users(id) on delete set null,
  reason varchar(500) not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  revoked_at timestamptz,
  revoked_by bigint references users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists user_bans_user_idx
  on user_bans(user_id, created_at desc);

create index if not exists user_bans_active_idx
  on user_bans(user_id, revoked_at, ends_at);
