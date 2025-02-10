# Lib's Notes

## Useful Commands

```bash
 psql $DATABASE_URL # start the db
```


```sql
>SHOW config_file;
                   config_file
-------------------------------------------------
 /opt/homebrew/var/postgresql@15/postgresql.conf
(1 row)

>SHOW data_directory;
         data_directory
---------------------------------
 /opt/homebrew/var/postgresql@15
```

```bash
code  /opt/homebrew/var/postgresql@15/postgresql.conf

pg_ctl restart \
--pgdata "/opt/homebrew/var/postgresql@15"

# echo "Set PGDATA: $PGDATA"


psql -U libby -d rideshare_development
```


## Setup

<!-- For initial setup -->
```bash
>export DB_URL="postgres://postgres:@localhost:5432/postgres"
>echo $DB_URL
postgres://postgres:@localhost:5432/postgres


>export RIDESHARE_DB_PASSWORD=$(openssl rand -hex 12)
>echo $RIDESHARE_DB_PASSWORD
15d0bc1ac663aa5ea1be8644


# <!-- from env comes after setup run-->
export DATABASE_URL=postgres://owner:@localhost:5432/rideshare_development

>echo $DATABASE_URL
postgres://owner:@localhost:5432/rideshare_development




psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle
connection to server at "localhost" (::1), port 5432 failed: FATAL:  role "postgres" does not exist
psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle



# ~20,000
bin/rails data_generators:generate_all


# 10,000,000
cd db
time sh scripts/bulk_load.sh

```

### Chapter 3 - data

for postgresql 15

```sql
FROM GENERATE_SERIES(1, 10_000_000) seq; -- => 10000000
```



### Changing Config file

/opt/homebrew/var/postgresql@15/postgresql.conf

```conf
shared_preload_libraries = 'pg_stat_statements'
```



### Tracking Columns with Sensitive Information

```sql
COMMENT ON COLUMN users.email IS 'sensitive_data=true';
```

https://guides.rubyonrails.org/active_record_migrations.html#comments

https://www.bigbinary.com/blog/rails-5-supports-adding-comments-migrations


## Useful SQL
```sql
SELECT * FROM pg_roles;

SELECT current_user;

SELECT * FROM pg_stat_activity
WHERE pid = (SELECT 79473);

-- select the count of users
SELECT COUNT(*) FROM users;


```



## SQL from book

### Starting an Email Scrubber Function

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

CREATE UNIQUE INDEX index_users_on_last_name2
ON users_copy USING btree (last_name);

ERROR:  could not create unique index "index_users_on_last_name2"
DETAIL:  Key (last_name)=(Lakin) is duplicated.
STATEMENT:  CREATE UNIQUE INDEX index_users_on_last_name2
	ON users_copy USING btree (last_name);
ERROR:  could not create unique index "index_users_on_last_name2"
DETAIL:  Key (last_name)=(Lakin) is duplicated.




CREATE UNIQUE INDEX users_pkey2
ON users_copy USING btree (id);
