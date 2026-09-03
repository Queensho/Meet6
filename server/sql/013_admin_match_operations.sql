alter table matches
  add column if not exists source_room_id bigint references rooms(id) on delete set null;

alter table matches
  add column if not exists unmatched_reason varchar(40);

alter table matches
  add column if not exists unmatched_by_user_id bigint references users(id) on delete set null;

alter table matches
  add column if not exists ended_by_admin_id bigint references users(id) on delete set null;

alter table matches
  add column if not exists admin_end_reason varchar(240);

create index if not exists matches_source_room_idx
  on matches(source_room_id, created_at desc);

create index if not exists matches_admin_status_idx
  on matches(unmatched_at, created_at desc);

-- Older matches did not persist their source room. Recover it from the
-- reciprocal secret selections when a latest candidate is available.
update matches m
set source_room_id = (
  select s1.room_id
  from room_selections s1
  join room_selections s2
    on s2.room_id = s1.room_id
   and s2.user_id = s1.selected_user_id
   and s2.selected_user_id = s1.user_id
  where s1.user_id = m.user_a_id
    and s1.selected_user_id = m.user_b_id
    and greatest(s1.updated_at, s2.updated_at) <= m.created_at + interval '2 minutes'
  order by greatest(s1.updated_at, s2.updated_at) desc
  limit 1
)
where m.source_room_id is null;

-- RoomService inserts a match immediately after reciprocal selection. Keep
-- the origin durable without coupling every caller to the new column.
create or replace function meet6_assign_match_source_room()
returns trigger
language plpgsql
as $$
begin
  if new.source_room_id is null then
    select s1.room_id into new.source_room_id
    from room_selections s1
    join room_selections s2
      on s2.room_id = s1.room_id
     and s2.user_id = s1.selected_user_id
     and s2.selected_user_id = s1.user_id
    where s1.user_id = new.user_a_id
      and s1.selected_user_id = new.user_b_id
    order by greatest(s1.updated_at, s2.updated_at) desc
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists matches_assign_source_room on matches;
create trigger matches_assign_source_room
before insert on matches
for each row execute function meet6_assign_match_source_room();
