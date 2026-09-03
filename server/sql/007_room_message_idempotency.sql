alter table room_messages
  add column if not exists client_message_id varchar(96);

create unique index if not exists room_messages_client_message_unique
  on room_messages(room_id, sender_user_id, client_message_id)
  where client_message_id is not null;

create index if not exists room_messages_client_lookup_idx
  on room_messages(room_id, sender_user_id, client_message_id)
  where client_message_id is not null;
