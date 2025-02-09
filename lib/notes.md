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
