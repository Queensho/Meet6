create table if not exists matchmaking_queue (
  user_id bigint primary key references users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

create index if not exists matchmaking_queue_joined_idx
  on matchmaking_queue(joined_at asc);

create table if not exists rooms (
  id bigserial primary key,
  status varchar(20) not null default 'active'
    check (status in ('active','selection','closed')),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null default (now() + interval '15 minutes'),
  extended boolean not null default false,
  selection_started_at timestamptz,
  selection_ends_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists rooms_status_idx on rooms(status);

create table if not exists room_members (
  room_id bigint not null references rooms(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (room_id, user_id)
);

create index if not exists room_members_user_idx
  on room_members(user_id, room_id desc);

create table if not exists room_messages (
  id bigserial primary key,
  room_id bigint not null references rooms(id) on delete cascade,
  sender_user_id bigint references users(id) on delete set null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists room_messages_room_idx
  on room_messages(room_id, id asc);

create table if not exists room_extension_votes (
  room_id bigint not null references rooms(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  vote boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(room_id, user_id)
);

create table if not exists room_selections (
  room_id bigint not null references rooms(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  selected_user_id bigint not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(room_id, user_id),
  check(user_id <> selected_user_id)
);

create table if not exists user_settings (
  user_id bigint primary key references users(id) on delete cascade,
  notifications_enabled boolean not null default true,
  room_reminders boolean not null default true,
  show_online boolean not null default true,
  precise_location boolean not null default false,
  vibration boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists notifications (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  type varchar(40) not null,
  title varchar(160) not null,
  body varchar(500) not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on notifications(user_id, created_at desc);

create table if not exists reports (
  id bigserial primary key,
  reporter_user_id bigint not null references users(id) on delete cascade,
  reported_user_id bigint not null references users(id) on delete cascade,
  room_id bigint references rooms(id) on delete set null,
  reason varchar(120) not null,
  detail varchar(1000),
  status varchar(20) not null default 'open',
  created_at timestamptz not null default now(),
  check(reporter_user_id <> reported_user_id)
);

create index if not exists reports_status_idx on reports(status, created_at desc);

-- Avoid duplicate active participation caused by repeated queue requests.
create unique index if not exists room_members_one_open_room_per_user
  on room_members(user_id)
  where left_at is null;
