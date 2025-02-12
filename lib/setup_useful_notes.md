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
export DB_URL="postgres://postgres:@localhost:5432/postgres"
echo $DB_URL
postgres://postgres:@localhost:5432/postgres


export RIDESHARE_DB_PASSWORD=$(openssl rand -hex 12)
echo $RIDESHARE_DB_PASSWORD
19e8d2e36117e8fffc273507

# <!-- from env comes after setup run-->
export DATABASE_URL=postgres://owner:@localhost:5432/rideshare_development

>echo $DATABASE_URL
postgres://owner:@localhost:5432/rideshare_development



psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle
connection to server at "localhost" (::1), port 5432 failed: FATAL:  role "postgres" does not exist
psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle


# setup and reset up
# need to set these before doing the reset
export RIDESHARE_DB_PASSWORD=$(openssl rand -hex 12)
export DB_URL="postgres://postgres:@localhost:5432/postgres"
bin/rails db:reset

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
