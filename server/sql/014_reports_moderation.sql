alter table reports
  add column if not exists match_id bigint references matches(id) on delete set null;

alter table reports
  add column if not exists moderator_note varchar(2000);

alter table reports
  add column if not exists reviewed_by_admin_id bigint references users(id) on delete set null;

alter table reports
  add column if not exists reviewed_at timestamptz;

alter table reports
  add column if not exists resolved_at timestamptz;

alter table reports
  add column if not exists resolution varchar(40);

alter table reports
  add column if not exists updated_at timestamptz not null default now();

update reports
set status='open'
where status not in ('open','reviewing','resolved','rejected');

create index if not exists reports_moderation_status_idx
  on reports(status, created_at desc);

create index if not exists reports_reported_history_idx
  on reports(reported_user_id, created_at desc);

create index if not exists reports_match_idx
  on reports(match_id, created_at desc);

create table if not exists report_moderation_notes (
  id bigserial primary key,
  report_id bigint not null references reports(id) on delete cascade,
  admin_user_id bigint references users(id) on delete set null,
  note varchar(2000) not null,
  created_at timestamptz not null default now()
);

create index if not exists report_moderation_notes_report_idx
  on report_moderation_notes(report_id, created_at desc);

-- Immutable evidence snapshots. They intentionally keep the message body even
-- if the original chat message is later deleted, so moderation evidence is not
-- lost after a report is submitted.
create table if not exists report_evidence_messages (
  id bigserial primary key,
  report_id bigint not null references reports(id) on delete cascade,
  source_type varchar(30) not null
    check (source_type in ('room_message','private_message')),
  source_message_id bigint not null,
  sender_user_id bigint references users(id) on delete set null,
  body text not null,
  message_created_at timestamptz not null,
  is_key_evidence boolean not null default false,
  created_at timestamptz not null default now(),
  unique(report_id, source_type, source_message_id)
);

create index if not exists report_evidence_messages_report_idx
  on report_evidence_messages(report_id, message_created_at asc);
