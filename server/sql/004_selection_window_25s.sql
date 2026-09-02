create or replace function meet6_set_selection_window()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'selection' and old.status is distinct from 'selection' then
    new.selection_started_at := coalesce(new.selection_started_at, now());
    new.selection_ends_at := new.selection_started_at + interval '25 seconds';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_meet6_set_selection_window on rooms;
create trigger trg_meet6_set_selection_window
before update on rooms
for each row
execute function meet6_set_selection_window();

-- If a selection room already exists during deployment, shorten its remaining
-- window as well instead of leaving the previous five-minute value in place.
update rooms
set selection_started_at = coalesce(selection_started_at, now()),
    selection_ends_at = least(
      coalesce(selection_ends_at, now() + interval '25 seconds'),
      coalesce(selection_started_at, now()) + interval '25 seconds'
    )
where status = 'selection';

create or replace function meet6_reject_late_room_selection()
returns trigger
language plpgsql
as $$
declare
  current_status text;
  deadline timestamptz;
begin
  select status, selection_ends_at
    into current_status, deadline
  from rooms
  where id = new.room_id;

  if current_status is distinct from 'selection'
     or deadline is null
     or deadline <= now() then
    raise exception 'Gizli seçim süresi doldu.' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_meet6_reject_late_room_selection on room_selections;
create trigger trg_meet6_reject_late_room_selection
before insert or update on room_selections
for each row
execute function meet6_reject_late_room_selection();
