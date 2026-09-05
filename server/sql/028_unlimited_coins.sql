alter table user_wallets
  add column if not exists unlimited_coins boolean not null default false;
