# Lib's Notes

## Useful Commands

```bash
 psql $DATABASE_URL # start the db
```

```sql



```




## Other


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
pg_ctl restart \
--pgdata "/opt/homebrew/var/postgresql@15"

# echo "Set PGDATA: $PGDATA"


psql -U libby -d rideshare_development


SELECT * FROM pg_roles;

SELECT current_user;

SELECT * FROM pg_stat_activity
WHERE pid = (SELECT 79473);

```



## Setup

<!-- >echo $DB_URL

export DB_URL="postgres://libby:@localhost:5432/postgres" -->

<!-- from env -->
export DATABASE_URL=postgres://owner:@localhost:5432/rideshare_development

>echo $DATABASE_URL
postgres://owner:@localhost:5432/rideshare_development


>echo $RIDESHARE_DB_PASSWORD
bb5100037979d77dea4c05fc



psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle
connection to server at "localhost" (::1), port 5432 failed: FATAL:  role "postgres" does not exist
psql: error: connection to server at "localhost" (::1), port 5432 failed: could not initiate GSSAPI security context:  The operation or option is not available: Credential for asked mech-type mech not found in the credential handle
