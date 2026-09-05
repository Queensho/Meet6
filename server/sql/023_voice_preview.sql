alter table rooms
  add column if not exists voice_stage varchar(16);

update rooms
set voice_stage='main'
where room_mode='voice' and voice_stage is null;

create table if not exists voice_preview_decisions (
  room_id bigint not null references rooms(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  decision boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create index if not exists voice_preview_decisions_room_idx
  on voice_preview_decisions(room_id, decision);
