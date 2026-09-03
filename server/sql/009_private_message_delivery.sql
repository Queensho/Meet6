alter table private_messages
  add column if not exists delivered_at timestamptz;

create index if not exists private_messages_match_delivery_idx
  on private_messages(match_id, sender_user_id, delivered_at, read_at);
