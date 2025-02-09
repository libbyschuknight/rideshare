ALTER TABLE users
ALTER COLUMN first_name SET STATISTICS 5000;
ANALYZE users;

SELECT
  attname,
  n_distinct,
  most_common_vals
FROM pg_stats
WHERE schemaname = 'rideshare'
AND tablename = 'users'
AND attname = 'first_name';

ALTER TABLE users
ALTER COLUMN first_name SET STATISTICS 100;
ANALYZE users;
