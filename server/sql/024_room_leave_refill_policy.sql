-- Voluntary room exits use admin_removed_at only as an active-membership visibility
-- marker so existing room snapshots/counts exclude the departed user. Do not emit
-- a moderation-removal notification unless an actual admin performed the removal.
create or replace function meet6_notify_admin_room_member_removed()
returns trigger
language plpgsql
as $$
begin
  if old.admin_removed_at is null
     and new.admin_removed_at is not null
     and new.admin_removed_by is not null then
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
