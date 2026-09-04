alter table rooms
  add column if not exists room_mode varchar(16) not null default 'text';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'rooms_room_mode_check'
  ) then
    alter table rooms
      add constraint rooms_room_mode_check
      check (room_mode in ('text', 'voice'));
  end if;
end $$;

create index if not exists rooms_mode_status_idx
  on rooms(room_mode, status, started_at desc);

create table if not exists voice_matchmaking_queue (
  user_id bigint primary key references users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

create index if not exists voice_matchmaking_queue_joined_idx
  on voice_matchmaking_queue(joined_at asc);
