alter table rooms drop constraint if exists rooms_room_mode_check;
alter table rooms
  add constraint rooms_room_mode_check
  check (room_mode in ('text', 'voice', 'game'));
