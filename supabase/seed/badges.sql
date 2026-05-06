insert into badges (code, name, description) values
  ('good_company', 'Good Company', 'Spent quality time with others in the lounge.'),
  ('regular',       'Regular',      'You show up. Night after night.'),
  ('palate_pro',    'Palate Pro',   'Your reviews carry weight.'),
  ('first_light',   'First Light',  'Lit your first cigar in The Final Third.'),
  ('ember',         'Ember',        'Started a streak.'),
  ('flame',         'Flame',        'Seven nights in a row.'),
  ('fire',          'Fire',         'Thirty nights in a row.')
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description;
