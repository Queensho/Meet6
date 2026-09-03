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

-- Older app builds did not persist match_id on a private-chat report. Recover
-- the match only when that pair had a match active at the time of the report.
update reports r
set match_id = (
  select m.id
  from matches m
  where least(m.user_a_id,m.user_b_id)=least(r.reporter_user_id,r.reported_user_id)
    and greatest(m.user_a_id,m.user_b_id)=greatest(r.reporter_user_id,r.reported_user_id)
    and m.created_at <= r.created_at
    and (m.unmatched_at is null or m.unmatched_at >= r.created_at)
  order by m.created_at desc
  limit 1
)
where r.room_id is null and r.match_id is null;

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

-- Backfill existing room reports with the 60 latest human messages that were
-- already present when the report was submitted.
insert into report_evidence_messages(
  report_id, source_type, source_message_id, sender_user_id,
  body, message_created_at
)
select r.id, 'room_message', snapshot.id, snapshot.sender_user_id,
       snapshot.body, snapshot.created_at
from reports r
join lateral (
  select m.id, m.sender_user_id, m.body, m.created_at
  from room_messages m
  where m.room_id=r.room_id
    and m.sender_user_id is not null
    and m.created_at <= r.created_at
  order by m.id desc
  limit 60
) snapshot on true
where r.room_id is not null
on conflict do nothing;

-- Backfill private-chat reports the same way after match_id recovery.
insert into report_evidence_messages(
  report_id, source_type, source_message_id, sender_user_id,
  body, message_created_at
)
select r.id, 'private_message', snapshot.id, snapshot.sender_user_id,
       snapshot.body, snapshot.created_at
from reports r
join lateral (
  select m.id, m.sender_user_id, m.body, m.created_at
  from private_messages m
  where m.match_id=r.match_id
    and m.created_at <= r.created_at
  order by m.id desc
  limit 60
) snapshot on true
where r.match_id is not null
on conflict do nothing;
