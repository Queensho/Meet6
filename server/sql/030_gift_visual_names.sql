-- Replace the old emoji-only free wave with the new H1/selam PNG.
update gift_catalog
set active=false,
    is_daily_free=false,
    updated_at=now()
where code='free_wave';

-- Keep stable internal gift codes, but make their visible names match the PNGs.
update gift_catalog
set name = case code
      when 'rose' then 'Selam'
      when 'coffee' then 'Kalp'
      when 'heart' then 'Hediye'
      when 'sparkle' then 'Sürpriz'
      when 'balloon' then 'Parti'
      when 'rocket' then 'Taç'
      when 'diamond' then 'Kahve'
      when 'crown' then 'Gül'
      else name
    end,
    emoji = case code
      when 'rose' then '👋'
      when 'coffee' then '💚'
      when 'heart' then '🎁'
      when 'sparkle' then '🎀'
      when 'balloon' then '🎉'
      when 'rocket' then '👑'
      when 'diamond' then '☕'
      when 'crown' then '🌹'
      else emoji
    end,
    coin_cost = case when code='rose' then 0 else coin_cost end,
    gift_xp = case when code='rose' then 1 else gift_xp end,
    generosity_xp = case when code='rose' then 1 else generosity_xp end,
    profile_xp = case when code='rose' then 1 else profile_xp end,
    is_daily_free = (code='rose'),
    sort_order = case code
      when 'rose' then 0
      when 'coffee' then 10
      when 'heart' then 20
      when 'sparkle' then 30
      when 'balloon' then 40
      when 'rocket' then 50
      when 'diamond' then 60
      when 'crown' then 70
      else sort_order
    end,
    active=true,
    updated_at=now()
where code in ('rose','coffee','heart','sparkle','balloon','rocket','diamond','crown');
