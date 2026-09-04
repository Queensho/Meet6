create table if not exists photo_moderation_items (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  original_name varchar(255),
  mime_type varchar(80) not null,
  sha256 char(64) not null,
  status varchar(24) not null
    check (status in ('approved','review','rejected')),
  provider varchar(40) not null,
  provider_result jsonb not null default '{}'::jsonb,
  reason varchar(500),
  public_url text,
  quarantine_path text,
  reviewed_by_admin_id bigint references users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists photo_moderation_user_idx
  on photo_moderation_items(user_id, created_at desc);

create index if not exists photo_moderation_queue_idx
  on photo_moderation_items(status, created_at asc);

create index if not exists photo_moderation_hash_idx
  on photo_moderation_items(sha256, created_at desc);

create table if not exists safety_events (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  event_type varchar(60) not null,
  score integer not null default 0 check (score between 0 and 100),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists safety_events_user_idx
  on safety_events(user_id, created_at desc);

create index if not exists safety_events_type_idx
  on safety_events(event_type, created_at desc);

create table if not exists user_risk_profiles (
  user_id bigint primary key references users(id) on delete cascade,
  risk_score integer not null default 0 check (risk_score between 0 and 100),
  risk_level varchar(20) not null default 'low'
    check (risk_level in ('low','medium','high','critical')),
  report_score integer not null default 0,
  spam_score integer not null default 0,
  fake_score integer not null default 0,
  restricted_until timestamptz,
  restriction_reason varchar(500),
  last_evaluated_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_risk_profiles_level_idx
  on user_risk_profiles(risk_level, risk_score desc, updated_at desc);

alter table reports
  add column if not exists priority_score integer not null default 0;

alter table reports
  add column if not exists triage_flags jsonb not null default '{}'::jsonb;

create index if not exists reports_priority_queue_idx
  on reports(status, priority_score desc, created_at asc);
