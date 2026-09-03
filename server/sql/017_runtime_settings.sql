create table if not exists app_runtime_settings (
  id smallint primary key default 1 check (id = 1),
  room_duration_minutes integer not null default 15 check (room_duration_minutes between 1 and 120),
  extension_minutes integer not null default 5 check (extension_minutes between 1 and 60),
  selection_seconds integer not null default 10 check (selection_seconds between 5 and 120),
  room_repeat_hours integer not null default 24 check (room_repeat_hours between 1 and 720),
  recent_match_days integer not null default 7 check (recent_match_days between 1 and 365),
  minimum_room_users integer not null default 6 check (minimum_room_users between 2 and 6),
  maintenance_mode boolean not null default false,
  maintenance_message varchar(500) not null default 'Meet6 kısa süreli bakımda. Lütfen biraz sonra tekrar dene.',
  announcement_enabled boolean not null default false,
  announcement_title varchar(120),
  announcement_message varchar(1000),
  updated_at timestamptz not null default now(),
  updated_by_admin_id bigint references users(id) on delete set null
);

insert into app_runtime_settings(id)
values(1)
on conflict(id) do nothing;
