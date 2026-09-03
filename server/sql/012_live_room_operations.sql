alter table room_members
  add column if not exists connection_count integer not null default 1;

alter table room_members
  add column if not exists last_connected_at timestamptz;

alter table room_members
  add column if not exists admin_removed_at timestamptz;

alter table room_members
  add column if not exists admin_removed_by bigint references users(id) on delete set null;

alter table room_members
  add column if not exists leave_reason varchar(120);

alter table rooms
  add column if not exists closed_reason varchar(240);

alter table rooms
  add column if not exists closed_by_admin_id bigint references users(id) on delete set null;

create index if not exists room_members_room_active_idx
  on room_members(room_id, left_at);

create index if not exists room_members_admin_removed_idx
  on room_members(room_id, admin_removed_at)
  where admin_removed_at is not null;
