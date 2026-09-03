create table if not exists admin_users (
  user_id bigint primary key references users(id) on delete cascade,
  role varchar(24) not null default 'support'
    check (role in ('super_admin','moderator','support')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_users_active_role_idx
  on admin_users(active, role);

create table if not exists admin_audit_log (
  id bigserial primary key,
  admin_user_id bigint references users(id) on delete set null,
  action varchar(80) not null,
  target_type varchar(40),
  target_id varchar(120),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_idx
  on admin_audit_log(created_at desc);

create index if not exists admin_audit_log_admin_idx
  on admin_audit_log(admin_user_id, created_at desc);
