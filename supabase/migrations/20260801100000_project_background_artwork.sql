-- Keep existing catalog IDs and ownership while replacing flat color previews
-- with the supplied watercolor artwork in the iOS asset catalog.
update public.star_sku_catalog
set asset_name = case id
  when 'background_sakura' then 'ProjectBackgroundSakura'
  when 'background_lemon' then 'ProjectBackgroundLemon'
  when 'background_sky' then 'ProjectBackgroundSky'
  when 'background_mint' then 'ProjectBackgroundMint'
  when 'background_lavender' then 'ProjectBackgroundLavender'
  else asset_name
end
where id in (
  'background_sakura',
  'background_lemon',
  'background_sky',
  'background_mint',
  'background_lavender'
);
