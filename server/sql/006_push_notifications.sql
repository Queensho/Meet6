create table if not exists push_device_tokens (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  token text not null unique,
  platform varchar(16) not null check (platform in ('android','ios','web')),
  app_instance_id varchar(160),
  enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_device_tokens_user_idx
  on push_device_tokens(user_id, enabled, updated_at desc);

alter table notifications
  add column if not exists push_claimed_at timestamptz,
  add column if not exists push_processed_at timestamptz,
  add column if not exists push_sent_at timestamptz,
  add column if not exists push_attempts integer not null default 0,
  add column if not exists push_error varchar(500);

create index if not exists notifications_push_outbox_idx
  on notifications(push_processed_at, id)
  where push_processed_at is null;

create or replace function meet6_notify_room_ready()
returns trigger
language plpgsql
as $$
declare
  member_count integer;
begin
  select count(*) into member_count
  from room_members
  where room_id = new.room_id and left_at is null;

  if member_count = 6 then
    insert into notifications(user_id, type, title, body, data)
    select rm.user_id,
           'room_found',
           'Odan hazır!',
           '6 kişi hazır. Sohbet başlıyor.',
           jsonb_build_object('roomId', new.room_id::text)
    from room_members rm
    where rm.room_id = new.room_id and rm.left_at is null
      and not exists (
        select 1 from notifications n
        where n.user_id = rm.user_id
          and n.type = 'room_found'
          and n.data->>'roomId' = new.room_id::text
      );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_meet6_room_ready_push on room_members;
create trigger trg_meet6_room_ready_push
after insert on room_members
for each row execute function meet6_notify_room_ready();
