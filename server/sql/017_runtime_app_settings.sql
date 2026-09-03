create table if not exists app_settings (
  key varchar(80) primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by_admin_id bigint references users(id) on delete set null
);

insert into app_settings(key, value) values
  ('room_duration_minutes', '15'::jsonb),
  ('room_extension_minutes', '5'::jsonb),
  ('selection_seconds', '10'::jsonb),
  ('room_repeat_hours', '24'::jsonb),
  ('recent_match_days', '7'::jsonb),
  ('minimum_users', '6'::jsonb),
  ('maintenance_mode', 'false'::jsonb),
  ('announcement_enabled', 'false'::jsonb),
  ('announcement_title', '""'::jsonb),
  ('announcement_body', '""'::jsonb)
on conflict(key) do nothing;

create index if not exists app_settings_updated_idx
  on app_settings(updated_at desc);
