-- Matchmaking history/safety lookups need to stay cheap as the user base grows.
create index if not exists rooms_started_at_idx
  on rooms(started_at desc);

create index if not exists matches_pair_history_idx
  on matches(user_a_id, user_b_id, created_at desc);

create index if not exists reports_reporter_reported_idx
  on reports(reporter_user_id, reported_user_id, created_at desc);

create index if not exists reports_reported_reporter_idx
  on reports(reported_user_id, reporter_user_id, created_at desc);
