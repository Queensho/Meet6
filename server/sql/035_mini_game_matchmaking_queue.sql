create table if not exists mini_game_matchmaking_queue (
  user_id bigint primary key references users(id) on delete cascade,
  game_key text not null check (game_key in ('red_flag_green_flag','two_truths_one_lie')),
  joined_at timestamptz not null default now()
);

create index if not exists idx_mini_game_matchmaking_queue_game_joined
  on mini_game_matchmaking_queue(game_key, joined_at);
