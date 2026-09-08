create table if not exists tabu_words (
  id bigserial primary key,
  word varchar(120) not null,
  category varchar(80) not null default 'genel',
  difficulty varchar(20) not null default 'normal' check (difficulty in ('kolay','normal','zor')),
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists tabu_words_word_unique
  on tabu_words (lower(word));
create index if not exists tabu_words_enabled_idx
  on tabu_words (enabled, category, difficulty);

create table if not exists tabu_forbidden_words (
  id bigserial primary key,
  tabu_word_id bigint not null references tabu_words(id) on delete cascade,
  word varchar(120) not null,
  unique(tabu_word_id, word)
);

create index if not exists tabu_forbidden_word_id_idx
  on tabu_forbidden_words(tabu_word_id);

create table if not exists tabu_word_history (
  user_id bigint not null references users(id) on delete cascade,
  tabu_word_id bigint not null references tabu_words(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key(user_id, tabu_word_id)
);

create index if not exists tabu_word_history_recent_idx
  on tabu_word_history(user_id, seen_at desc);

create table if not exists tabu_game_xp_events (
  id bigserial primary key,
  room_id bigint not null references rooms(id) on delete cascade,
  user_id bigint not null references users(id) on delete cascade,
  event_key varchar(120) not null,
  delta integer not null,
  created_at timestamptz not null default now(),
  unique(room_id, user_id, event_key)
);
