-- Notification hardening:
-- 1) room-ready push follows runtime minimum_room_users instead of hardcoded 6
-- 2) ban/unban always generates an account-status notification regardless of
--    which admin service performs the moderation action
-- 3) moderation notification duplicates for the same ban are suppressed

create or replace function meet6_notify_room_ready()
returns trigger
language plpgsql
as $$
declare
  member_count integer;
  required_count integer := 6;
begin
  select coalesce(minimum_room_users, 6)
    into required_count
  from app_runtime_settings
  where id = 1;

  required_count := coalesce(required_count, 6);

  select count(*) into member_count
  from room_members
  where room_id = new.room_id
    and left_at is null
    and admin_removed_at is null;

  if member_count >= required_count then
    insert into notifications(user_id, type, title, body, data)
    select rm.user_id,
           'room_found',
           'Odan hazır!',
           required_count::text || ' kişi hazır. Sohbet başlıyor.',
           jsonb_build_object('roomId', new.room_id::text)
    from room_members rm
    where rm.room_id = new.room_id
      and rm.left_at is null
      and rm.admin_removed_at is null
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

-- The old trigger already points at meet6_notify_room_ready(); recreating it
-- makes the dependency explicit for fresh and upgraded databases alike.
drop trigger if exists trg_meet6_room_ready_push on room_members;
create trigger trg_meet6_room_ready_push
after insert on room_members
for each row execute function meet6_notify_room_ready();

create or replace function meet6_dedupe_moderation_notification()
returns trigger
language plpgsql
as $$
begin
  if new.type in ('moderation_ban', 'moderation_unban')
     and coalesce(new.data->>'banId', '') <> ''
     and exists (
       select 1
       from notifications n
       where n.user_id = new.user_id
         and n.type = new.type
         and n.data->>'banId' = new.data->>'banId'
     ) then
    return null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_meet6_dedupe_moderation_notification on notifications;
create trigger trg_meet6_dedupe_moderation_notification
before insert on notifications
for each row execute function meet6_dedupe_moderation_notification();

create or replace function meet6_notify_ban_created()
returns trigger
language plpgsql
as $$
begin
  insert into notifications(user_id, type, title, body, data)
  values(
    new.user_id,
    'moderation_ban',
    'Meet6 hesap işlemi',
    coalesce(nullif(trim(new.reason), ''), 'Hesabına erişim kısıtlaması uygulandı.'),
    jsonb_build_object(
      'banId', new.id::text,
      'permanent', new.ends_at is null,
      'endsAt', case when new.ends_at is null then null else new.ends_at::text end,
      'forceDelivery', true
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_meet6_ban_created_notification on user_bans;
create trigger trg_meet6_ban_created_notification
after insert on user_bans
for each row execute function meet6_notify_ban_created();

create or replace function meet6_notify_ban_revoked()
returns trigger
language plpgsql
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    insert into notifications(user_id, type, title, body, data)
    values(
      new.user_id,
      'moderation_unban',
      'Meet6 banı kaldırıldı',
      'Hesabındaki erişim kısıtlaması kaldırıldı.',
      jsonb_build_object(
        'banId', new.id::text,
        'forceDelivery', true
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_meet6_ban_revoked_notification on user_bans;
create trigger trg_meet6_ban_revoked_notification
after update of revoked_at on user_bans
for each row execute function meet6_notify_ban_revoked();
