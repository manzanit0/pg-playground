# Logical replication

## TLDR

Question: How can I upgrade a postgres server with as little downtime as possible?
Answer: Set up logical replication and then point clients to the replicated server.

## Longer version

### This is actually old news

Apparently Postgres added logical replication in PG13, so extensions such as
`pglogical` aren't really needed.

- https://www.postgresql.org/docs/current/logical-replication.html
- https://github.com/2ndQuadrant/pglogical

### We need to run migrations separately

Logical replication is only for data and only in regular tables, i,e, not views. Schema definitions are NOT propagated.

> (...) each (active) subscription receives changes from a replication slot on the remote (publishing) side.

This means that the new server should have all the schema definitions up to date before starting replication.


### Ensure `wal_level` and other settings are correctly configured

```
could not create replication slot "target_subscription": ERROR:  logical decoding requires wal_level >= logical
```

### Actually setting up replication

Checkout the [main.tf][./terraform/main.tf]. That contains all the needed changes.

### Troubleshooting the replication

Wait, it's not working. How can I know what link is broken?


On the **publisher** side check:

1. The publication is correctly set up

```
postgres@localhost:test_db> select * from pg_catalog.pg_publication
+-------+--------------------+----------+--------------+-----------+-----------+-----------+-------------+------------+
| oid   | pubname            | pubowner | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot |
|-------+--------------------+----------+--------------+-----------+-----------+-----------+-------------+------------|
| 20853 | source_publication | 10       | True         | True      | True      | True      | True        | False      |
+-------+--------------------+----------+--------------+-----------+-----------+-----------+-------------+------------+
SELECT 1
Time: 0.007s
```

2. The tables we expect are being published

```
postgres@localhost:test_db> select * from pg_catalog.pg_publication_tables
+--------------------+------------+-----------+-----------+-----------+
| pubname            | schemaname | tablename | attnames  | rowfilter |
|--------------------+------------+-----------+-----------+-----------|
| source_publication | public     | foo       | ['bar']   | <null>    |
| source_publication | public     | another   | ['thing'] | <null>    |
+--------------------+------------+-----------+-----------+-----------+
```

3. The last write-ahead log location -- we'll correlate this one with the subscriber.

```
postgres@localhost:test_db> select pg_current_wal_lsn();  
+--------------------+
| pg_current_wal_lsn |
|--------------------|
| 0/24F36B0          |
+--------------------+
SELECT 1
Time: 0.008s
```

On the **subscriber** side check that `latest_end_lsn` is the same as
`pg_current_wal_lsn` on the publisher. If they're not the same, then there's a
lag. The `latest_end_time` might help understand how much of a lag.

```
postgres@localhost:test_db> select * from pg_catalog.pg_stat_subscription
-[ RECORD 1 ]-------------------------
subid                 | 20850
subname               | target_subscription
worker_type           | apply
pid                   | 1346
leader_pid            | <null>
relid                 | <null>
received_lsn          | 0/24F3AD8
last_msg_send_time    | 2024-12-23 23:21:05.085627+00
last_msg_receipt_time | 2024-12-23 23:21:05.085737+00
latest_end_lsn        | 0/24F3AD8
latest_end_time       | 2024-12-23 23:21:05.085627+00
SELECT 1
Time: 0.004s
```

### If you just added that table, kick the subscription

When new tables are added, we need to refresh the publication:

```
postgres@localhost:test_db> ALTER SUBSCRIPTION target_subscription REFRESH PUBLICATION;
```

ref: https://www.postgresql.org/docs/current/sql-altersubscription.html#SQL-ALTERSUBSCRIPTION-PARAMS-REFRESH-PUBLICATION

### Are we done now?

Once you have the replication working, now you just have to do the "blue-green" thing. Some food for thought:
* It's not really as easy as "swapping clients from one server to another". If
  for any reason multiple clients work over the same data, then there's room
  for data inconsistencies: replication IS NOT bidirectional. These would have
  to be troubleshot manually.
* IF you wanted to have replication go both ways, then you're looking at a
  multi-master set up. That's harder.
* Once you have replication up to speed, if you can afford _some_ downtime,
  then shutting down the publisher and pointing everyone to the subscriber will
  avoid you the inconsistencies.
* At this stage it's a bigger dish of trade-offs and picking your battle. With
  how much can you get away vs is the juice worth the squeeze.
