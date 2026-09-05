create or replace function preserve_unlimited_coin_balance()
returns trigger
language plpgsql
as $$
begin
  if old.unlimited_coins = true and new.unlimited_coins = true then
    new.coin_balance := old.coin_balance;
  end if;
  return new;
end;
$$;

drop trigger if exists user_wallets_preserve_unlimited_coins on user_wallets;
create trigger user_wallets_preserve_unlimited_coins
before update of coin_balance on user_wallets
for each row
execute function preserve_unlimited_coin_balance();
