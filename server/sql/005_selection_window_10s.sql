create or replace function meet6_set_selection_window()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'selection' and old.status is distinct from 'selection' then
    new.selection_started_at := coalesce(new.selection_started_at, now());
    new.selection_ends_at := new.selection_started_at + interval '10 seconds';
  end if;
  return new;
end;
$$;

-- Shorten any selection room that is already open while this migration is applied.
update rooms
set selection_started_at = coalesce(selection_started_at, now()),
    selection_ends_at = least(
      coalesce(selection_ends_at, now() + interval '10 seconds'),
      coalesce(selection_started_at, now()) + interval '10 seconds'
    )
where status = 'selection';
