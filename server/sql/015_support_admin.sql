alter table support_requests
  add column if not exists priority varchar(12) not null default 'normal';

alter table support_requests
  add column if not exists admin_response varchar(4000);

alter table support_requests
  add column if not exists responded_at timestamptz;

alter table support_requests
  add column if not exists responded_by_admin_id bigint references users(id) on delete set null;

alter table support_requests
  add column if not exists closed_at timestamptz;

alter table support_requests
  drop constraint if exists support_requests_status_check;

update support_requests
set status='answered'
where status='in_progress';

alter table support_requests
  add constraint support_requests_status_check
  check (status in ('open','answered','closed'));

alter table support_requests
  drop constraint if exists support_requests_priority_check;

alter table support_requests
  add constraint support_requests_priority_check
  check (priority in ('low','normal','high'));

create index if not exists support_requests_admin_queue_idx
  on support_requests(status, priority, created_at asc);

create index if not exists support_requests_priority_idx
  on support_requests(priority, created_at desc);
