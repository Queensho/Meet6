create table if not exists matchmaking_parties(
  id bigserial primary key,
  code varchar(8) not null unique,
  owner_user_id bigint not null references users(id) on delete cascade,
  guest_user_id bigint references users(id) on delete set null,
  room_mode varchar(16) not null,
  game_key varchar(64),
  room_duration_minutes int not null default 15,
  status varchar(24) not null default 'waiting_friend',
  room_id bigint references rooms(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes')
);

create index if not exists matchmaking_parties_owner_active_idx
  on matchmaking_parties(owner_user_id,status,created_at desc);
create index if not exists matchmaking_parties_guest_active_idx
  on matchmaking_parties(guest_user_id,status,created_at desc);
create index if not exists matchmaking_parties_room_idx
  on matchmaking_parties(room_id,status);

create or replace function meet6_reject_party_friend_selection()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from matchmaking_parties p
    where p.room_id = new.room_id
      and p.status = 'matched'
      and p.guest_user_id is not null
      and (
        (p.owner_user_id = new.user_id and p.guest_user_id = new.selected_user_id)
        or
        (p.guest_user_id = new.user_id and p.owner_user_id = new.selected_user_id)
      )
  ) then
    raise exception 'Davet ettiğin arkadaşını gizli seçimde seçemezsin.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_room_selection_party_guard on room_selections;
create trigger trg_room_selection_party_guard
before insert or update of selected_user_id on room_selections
for each row execute function meet6_reject_party_friend_selection();
