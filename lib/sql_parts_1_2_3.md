# SQL from book

## Starting an Email Scrubber Function

```sql
CREATE OR REPLACE FUNCTION SCRUB_EMAIL(email_address varchar(255))
RETURNS VARCHAR(255) AS $$
SELECT email_address;
$$ LANGUAGE SQL;


SELECT SCRUB_EMAIL(email)
FROM users
LIMIT 5;



SELECT SPLIT_PART('bob@example.com', '@', 1);
SELECT LENGTH('bob');


-- sql/scrub_email_function_full.sql
-- replace email_address with random text that is the same
-- length as the unique portion of an email address
-- before the "@" symbol.
-- Make the minimum length 5 characters to avoid
-- MD5 text generation collisions
CREATE OR REPLACE FUNCTION SCRUB_EMAIL(
  email_address VARCHAR(255)
) RETURNS VARCHAR(255) AS $$
SELECT
CONCAT(
  SUBSTR(
    MD5(RANDOM()::TEXT),
    0,
    GREATEST(
      LENGTH(
        SPLIT_PART(email_address, '@', 1)
      ) + 1, 6
    )
  ),
  '@',
  SPLIT_PART(email_address, '@', 2)
);
$$ LANGUAGE SQL;

SELECT SETSEED(0.5);
SELECT SCRUB_EMAIL('bob@gmail.com');
-- scrub_email
-- -------------------


SELECT SETSEED(0.5);
SELECT SCRUB_EMAIL('bob-and-jane@gmail.com');

```

### Understanding Clone and Replace Trade-Offs

```sql
-- sql/table_copying_create_like.sql
CREATE TABLE users_copy (LIKE users INCLUDING ALL);


-- sql/scrubbing_on_the_fly.sql
INSERT INTO users_copy(
  id, first_name, last_name,
  email, type, created_at, updated_at
)
(
  SELECT
  id, first_name, last_name,
  SCRUB_EMAIL(email),-- scrubber function
  type, created_at, updated_at
  FROM users
);



SELECT
  u1.email AS original,
  u2.email AS scrubbed
FROM users u1
JOIN users_copy u2 USING (id)
WHERE id = (SELECT MIN(id) FROM users);
```


### Speeding Up Inserts for Clone and Replace

```sql
-- sql/table_create_like_including_all_excluding_indexes.sql

DROP TABLE IF EXISTS users_copy;
CREATE TABLE users_copy (LIKE users INCLUDING ALL EXCLUDING INDEXES);


rideshare_development=> \d users_copy
                                            Table "rideshare.users_copy"
         Column         |              Type              | Collation | Nullable |              Default
------------------------+--------------------------------+-----------+----------+-----------------------------------
 id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
 first_name             | character varying              |           | not null |
 last_name              | character varying              |           | not null |
 email                  | character varying              |           | not null |
 type                   | character varying              |           | not null |
 created_at             | timestamp(6) without time zone |           | not null |
 updated_at             | timestamp(6) without time zone |           | not null |
 password_digest        | character varying              |           |          |
 trips_count            | integer                        |           |          |
 drivers_license_number | character varying(100)         |           |          |



rideshare_development=> \d users
                                              Table "rideshare.users"
         Column         |              Type              | Collation | Nullable |              Default
------------------------+--------------------------------+-----------+----------+-----------------------------------
 id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
 first_name             | character varying              |           | not null |
 last_name              | character varying              |           | not null |
 email                  | character varying              |           | not null |
 type                   | character varying              |           | not null |
 created_at             | timestamp(6) without time zone |           | not null |
 updated_at             | timestamp(6) without time zone |           | not null |
 password_digest        | character varying              |           |          |
 trips_count            | integer                        |           |          |
 drivers_license_number | character varying(100)         |           |          |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_email" UNIQUE, btree (email)
    "index_users_on_last_name" btree (last_name)
Referenced by:
    TABLE "trip_requests" CONSTRAINT "fk_rails_c17a139554" FOREIGN KEY (rider_id) REFERENCES users(id)
    TABLE "trips" CONSTRAINT "fk_rails_e7560abc33" FOREIGN KEY (driver_id) REFERENCES users(id)


-- sql/list_all_constraints.sql
-- list constraints in 'rideshare' schema
SELECT
  conrelid::regclass AS table_name,
  conname AS foreign_key,
  PG_GET_CONSTRAINTDEF(oid)
FROM pg_constraint
WHERE contype = 'f'
AND connamespace = 'rideshare'::regnamespace
ORDER BY conrelid::regclass::text, contype DESC;



-- sql/constraint_definition_ddl.sql
SELECT
  FORMAT(
    'ALTER TABLE %I.%I ADD CONSTRAINT %I %s;',
    connamespace::regnamespace,
    conrelid::regclass,
    conname,
    PG_GET_CONSTRAINTDEF(oid)
  )
FROM
  pg_constraint
WHERE
conname IN ('fk_rails_e7560abc33');

-- output
                                                    format
--------------------------------------------------------------------------------------------------------------
 ALTER TABLE rideshare.trips ADD CONSTRAINT fk_rails_e7560abc33 FOREIGN KEY (driver_id) REFERENCES users(id);
(1 row)
-- then used in next statement below


-- sql/create_table_like.sql
CREATE TABLE trips_copy (
  LIKE trips INCLUDING ALL EXCLUDING INDEXES
);
ALTER TABLE trips_copy
ADD CONSTRAINT fk_rails_e7560abc33 FOREIGN KEY (driver_id)
REFERENCES users(id);



-- sql/list_sequences_table_column_owner.sql
SELECT
  s.relname AS seq,
  n.nspname AS sch,
  t.relname AS tab,
  a.attname AS col
FROM
  pg_class s
JOIN pg_depend d ON d.objid = s.oid
AND d.classid = 'pg_class'::REGCLASS
AND d.refclassid = 'pg_class'::REGCLASS
JOIN pg_class t ON t.oid = d.refobjid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid
AND a.attnum = d.refobjsubid
WHERE
  s.relkind = 'S'
  AND d.deptype = 'a';


ALTER SEQUENCE users_id_seq OWNED BY users_copy.id;



-- Use the same trick from before, where you list the indexes as DDL creationstatements.
-- To do that, run the following query:
-- sql/list_users_table_indexes.sql
SELECT PG_GET_INDEXDEF(indexrelid) || ';' AS index
FROM pg_index
WHERE indrelid = 'users'::REGCLASS;

-- output
                                       index
-----------------------------------------------------------------------------------
 CREATE UNIQUE INDEX users_pkey ON rideshare.users USING btree (id);
 CREATE INDEX index_users_on_last_name ON rideshare.users USING btree (last_name);
 CREATE UNIQUE INDEX index_users_on_email ON rideshare.users USING btree (email);
(3 rows)


-- Let’s take a look at the UNIQUE index on the users.email column. To create that
-- index again, you’d run the following statement to create on the users_copy table:
-- sql/create_unique_index_users_email.sql
-- Temporarily adding "2" to the index name,
-- so that it's unique (can remove the "2" later)
CREATE UNIQUE INDEX index_users_on_email2
ON users_copy USING btree (email);

CREATE INDEX index_users_on_last_name2
ON users_copy USING btree (last_name);

-- not primary key ?
CREATE UNIQUE INDEX users_pkey2
ON users_copy USING btree (id);

-- add primary key
ALTER TABLE users_copy
ADD PRIMARY KEY (id);

-- drop users_pkey2 index
DROP INDEX users_pkey2;



-- sql/finalize_table_copying_users.sql
BEGIN;
-- drop the original table and related objects
DROP TABLE users CASCADE;
-- rename the destination table to be the source table name
ALTER TABLE users_copy RENAME TO users;
COMMIT;


\d users
                                              Table "rideshare.users"
         Column         |              Type              | Collation | Nullable |              Default
------------------------+--------------------------------+-----------+----------+-----------------------------------
 id                     | bigint                         |           | not null | nextval('users_id_seq'::regclass)
 first_name             | character varying              |           | not null |
 last_name              | character varying              |           | not null |
 email                  | character varying              |           | not null |
 type                   | character varying              |           | not null |
 created_at             | timestamp(6) without time zone |           | not null |
 updated_at             | timestamp(6) without time zone |           | not null |
 password_digest        | character varying              |           |          |
 trips_count            | integer                        |           |          |
 drivers_license_number | character varying(100)         |           |          |
Indexes:
    "users_copy_pkey" PRIMARY KEY, btree (id)
    "index_users_on_email2" UNIQUE, btree (email)
    "index_users_on_last_name2" btree (last_name)

-- Does not have the Referenced by:
```

### Using Direct Updates for Text Replacement

```sql
-- sql/direct_updates_users.sql
UPDATE users
SET email = SCRUB_EMAIL(email);

-- sql/vacuum_analyze_users.sql
VACUUM (ANALYZE, VERBOSE) users;


sql/reindex_users.sql
REINDEX INDEX index_users_on_email2;
```

### Performing Updates in Batches

```sql
-- sql/scrub_batched_direct_updates.sql
CREATE OR REPLACE PROCEDURE SCRUB_BATCHES()
LANGUAGE PLPGSQL
AS $$
DECLARE
  current_id INT := (SELECT MIN(id) FROM users);
  max_id INT := (SELECT MAX(id) FROM users);
  batch_size INT := 1000;
  rows_updated INT;
BEGIN
  WHILE current_id <= max_id LOOP
    -- the UPDATE by `id` range
    UPDATE users
    SET email = SCRUB_EMAIL(email)
    WHERE id >= current_id
    AND id < current_id + batch_size;
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    COMMIT;
    RAISE NOTICE 'current_id: % - Number of rows updated: %',
    current_id, rows_updated;
    current_id := current_id + batch_size + 1;
  END LOOP;
END;
$$;
-- Call the Procedure
CALL SCRUB_BATCHES();
```

### What’s Next for Your Performance Database
