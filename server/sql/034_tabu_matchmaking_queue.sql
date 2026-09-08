create table if not exists tabu_matchmaking_queue (
  user_id bigint primary key references users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

create index if not exists tabu_matchmaking_queue_joined_idx
  on tabu_matchmaking_queue(joined_at asc);
