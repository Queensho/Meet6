alter table users add column if not exists password_hash text;
alter table users add column if not exists password_salt text;
alter table users add column if not exists password_updated_at timestamptz;

create index if not exists users_password_ready_idx
  on users (id)
  where password_hash is not null and password_salt is not null;
