create table if not exists users (
  id bigserial primary key,
  phone_e164 varchar(20) not null unique,
  status varchar(20) not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table if not exists profiles (
  user_id bigint primary key references users(id) on delete cascade,
  display_name varchar(80),
  birth_date date,
  gender varchar(30),
  bio varchar(240),
  city varchar(100),
  country varchar(100),
  latitude double precision,
  longitude double precision,
  profile_prompt varchar(160),
  profile_answer varchar(240),
  interests text[] not null default '{}',
  photo_urls text[] not null default '{}',
  profile_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists matching_preferences (
  user_id bigint primary key references users(id) on delete cascade,
  looking_for varchar(40) not null default 'Herkes',
  min_age integer not null default 18 check (min_age >= 18),
  max_age integer not null default 65 check (max_age >= min_age),
  distance_km integer not null default 25 check (distance_km between 1 and 500),
  purpose varchar(80) not null default 'Yeni insanlarla tanışma',
  updated_at timestamptz not null default now()
);

create table if not exists blocked_users (
  blocker_user_id bigint not null references users(id) on delete cascade,
  blocked_user_id bigint not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table if not exists matches (
  id bigserial primary key,
  user_a_id bigint not null references users(id) on delete cascade,
  user_b_id bigint not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unmatched_at timestamptz,
  check (user_a_id <> user_b_id)
);

create unique index if not exists matches_pair_unique
  on matches (least(user_a_id, user_b_id), greatest(user_a_id, user_b_id))
  where unmatched_at is null;

create table if not exists private_messages (
  id bigserial primary key,
  match_id bigint not null references matches(id) on delete cascade,
  sender_user_id bigint not null references users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists private_messages_match_created_idx
  on private_messages(match_id, created_at desc);

create table if not exists otp_challenges (
  id bigserial primary key,
  phone_e164 varchar(20) not null,
  code_hash varchar(128) not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists otp_phone_created_idx
  on otp_challenges(phone_e164, created_at desc);
