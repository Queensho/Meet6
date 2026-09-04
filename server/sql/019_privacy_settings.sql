alter table user_settings
  add column if not exists allow_room_invites boolean not null default true,
  add column if not exists allow_private_messages boolean not null default true,
  add column if not exists hide_exact_distance boolean not null default true,
  add column if not exists read_receipts boolean not null default true;
