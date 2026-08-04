-- Keep catalog IDs and ownership stable while replacing temporary SF Symbols
-- with the final bundled Poco artwork.
update public.star_sku_catalog
set asset_name = case id
  when 'badge_first_light' then 'BadgeFirstLight'
  when 'badge_word_bouquet' then 'BadgeWordBouquet'
  when 'badge_poco_heart' then 'PocoCreatorHeartReceived'
  else asset_name
end
where id in (
  'badge_first_light',
  'badge_word_bouquet',
  'badge_poco_heart'
);
