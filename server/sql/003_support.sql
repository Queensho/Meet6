create table if not exists support_requests (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  topic varchar(80) not null,
  message varchar(2000) not null,
  status varchar(20) not null default 'open'
    check (status in ('open','in_progress','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_requests_user_idx
  on support_requests(user_id, created_at desc);

create index if not exists support_requests_status_idx
  on support_requests(status, created_at asc);
