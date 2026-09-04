-- Notification hardening:
-- 1) room-ready push follows runtime minimum_room_users instead of hardcoded 6
-- 2) ban/unban always generates an account-status notification regardless of
--    which admin service performs the moderation action
-- 3) moderation notification duplicates for the same ban are suppressed
-- 4) admin room close/remove and final report decisions notify affected users

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

create or replace function meet6_notify_admin_room_closed()
returns trigger
language plpgsql
as $$
begin
  if old.status is distinct from new.status
     and new.status = 'closed'
     and new.closed_by_admin_id is not null then
    insert into notifications(user_id, type, title, body, data)
    select rm.user_id,
           'room_closed',
           'Meet6 odası kapatıldı',
           coalesce(nullif(trim(new.closed_reason), ''), 'Oda moderasyon tarafından kapatıldı.'),
           jsonb_build_object(
             'roomId', new.id::text,
             'reason', new.closed_reason
           )
    from room_members rm
    where rm.room_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_meet6_admin_room_closed_notification on rooms;
create trigger trg_meet6_admin_room_closed_notification
after update of status on rooms
for each row execute function meet6_notify_admin_room_closed();

create or replace function meet6_notify_admin_room_member_removed()
returns trigger
language plpgsql
as $$
begin
  if old.admin_removed_at is null and new.admin_removed_at is not null then
    insert into notifications(user_id, type, title, body, data)
    values(
      new.user_id,
      'room_removed',
      'Meet6 odasından çıkarıldın',
      'Bu odadan moderasyon tarafından çıkarıldın.',
      jsonb_build_object('roomId', new.room_id::text)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_meet6_admin_room_member_removed_notification on room_members;
create trigger trg_meet6_admin_room_member_removed_notification
after update of admin_removed_at on room_members
for each row execute function meet6_notify_admin_room_member_removed();

create or replace function meet6_notify_report_final_status()
returns trigger
language plpgsql
as $$
begin
  if old.status is distinct from new.status
     and new.status in ('resolved', 'rejected') then
    insert into notifications(user_id, type, title, body, data)
    values(
      new.reporter_user_id,
      'report_update',
      'Şikâyetin incelendi',
      case
        when new.status = 'resolved' then 'Şikâyetin incelendi ve sonuçlandırıldı.'
        else 'Şikâyetin incelendi ve işlem tamamlandı.'
      end,
      jsonb_build_object(
        'reportId', new.id::text,
        'status', new.status
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_meet6_report_final_status_notification on reports;
create trigger trg_meet6_report_final_status_notification
after update of status on reports
for each row execute function meet6_notify_report_final_status();
