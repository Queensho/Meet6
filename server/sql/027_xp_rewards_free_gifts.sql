alter table gift_catalog
  drop constraint if exists gift_catalog_coin_cost_check;
alter table gift_catalog
  add constraint gift_catalog_coin_cost_check check (coin_cost >= 0);

alter table room_gifts
  drop constraint if exists room_gifts_coin_cost_check;
alter table room_gifts
  add constraint room_gifts_coin_cost_check check (coin_cost >= 0);

alter table gift_catalog
  add column if not exists profile_xp integer not null default 0 check (profile_xp >= 0);
alter table gift_catalog
  add column if not exists is_daily_free boolean not null default false;

alter table user_wallets
  add column if not exists profile_xp integer not null default 0 check (profile_xp >= 0);

update gift_catalog
set profile_xp = case code
  when 'rose' then 2
  when 'coffee' then 3
  when 'heart' then 5
  when 'sparkle' then 8
  when 'balloon' then 12
  when 'rocket' then 18
  when 'diamond' then 25
  when 'crown' then 35
  else profile_xp
end,
updated_at = now()
where code in ('rose','coffee','heart','sparkle','balloon','rocket','diamond','crown');

insert into gift_catalog(
  code,name,emoji,coin_cost,gift_xp,generosity_xp,profile_xp,sort_order,active,is_daily_free
)
values ('free_wave','Selam','👋',0,1,1,1,0,true,true)
on conflict(code) do update set
  name=excluded.name,
  emoji=excluded.emoji,
  coin_cost=excluded.coin_cost,
  gift_xp=excluded.gift_xp,
  generosity_xp=excluded.generosity_xp,
  profile_xp=excluded.profile_xp,
  sort_order=excluded.sort_order,
  active=excluded.active,
  is_daily_free=excluded.is_daily_free,
  updated_at=now();

create table if not exists user_daily_gift_usage (
  user_id bigint not null references users(id) on delete cascade,
  usage_date date not null default current_date,
  free_gifts_used integer not null default 0 check (free_gifts_used between 0 and 3),
  gift_profile_xp_earned integer not null default 0 check (gift_profile_xp_earned between 0 and 100),
  updated_at timestamptz not null default now(),
  primary key(user_id, usage_date)
);

create table if not exists xp_reward_catalog (
  reward_key varchar(80) primary key,
  level integer not null check (level between 2 and 30),
  reward_type varchar(32) not null check (reward_type in ('coins','premium_days','badge','frame','effect')),
  amount integer not null default 0 check (amount >= 0),
  title varchar(120) not null,
  cosmetic_code varchar(80),
  sort_order integer not null default 0,
  active boolean not null default true
);

insert into xp_reward_catalog(reward_key,level,reward_type,amount,title,cosmetic_code,sort_order,active)
values
  ('lv2_coins',2,'coins',25,'25 jeton',null,20,true),
  ('lv3_frame',3,'frame',0,'Lime profil çerçevesi','frame_lime',30,true),
  ('lv5_coins',5,'coins',75,'75 jeton',null,50,true),
  ('lv5_badge',5,'badge',0,'Yükselen rozet','badge_rising',51,true),
  ('lv7_premium',7,'premium_days',1,'1 günlük Premium',null,70,true),
  ('lv10_premium',10,'premium_days',3,'3 günlük Premium',null,100,true),
  ('lv10_frame',10,'frame',0,'Neon profil çerçevesi','frame_neon',101,true),
  ('lv12_coins',12,'coins',150,'150 jeton',null,120,true),
  ('lv15_premium',15,'premium_days',7,'7 günlük Premium',null,150,true),
  ('lv18_badge',18,'badge',0,'Animasyonlu yıldız rozeti','badge_animated_star',180,true),
  ('lv20_coins',20,'coins',300,'300 jeton',null,200,true),
  ('lv20_frame',20,'frame',0,'Elite profil çerçevesi','frame_elite',201,true),
  ('lv25_premium',25,'premium_days',7,'7 günlük Premium',null,250,true),
  ('lv30_badge',30,'badge',0,'Meet6 Elite rozeti','badge_meet6_elite',300,true),
  ('lv30_effect',30,'effect',0,'Elite oda efekti','effect_elite_room',301,true)
on conflict(reward_key) do update set
  level=excluded.level,
  reward_type=excluded.reward_type,
  amount=excluded.amount,
  title=excluded.title,
  cosmetic_code=excluded.cosmetic_code,
  sort_order=excluded.sort_order,
  active=excluded.active;

create table if not exists user_xp_reward_claims (
  user_id bigint not null references users(id) on delete cascade,
  reward_key varchar(80) not null references xp_reward_catalog(reward_key) on delete cascade,
  granted_at timestamptz not null default now(),
  primary key(user_id,reward_key)
);

create table if not exists premium_grants (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  source varchar(40) not null,
  source_key varchar(120) not null,
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique(user_id,source,source_key),
  check (expires_at > starts_at)
);

create index if not exists premium_grants_active_idx
  on premium_grants(user_id,starts_at,expires_at);
create index if not exists xp_reward_catalog_level_idx
  on xp_reward_catalog(level,sort_order);
