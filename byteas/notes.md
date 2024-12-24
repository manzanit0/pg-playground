
These are how long the queries take:
```
root@localhost:playground_db> select id, receipt_image from receipt_with_image
Time: 98.118s (1 minute 38 seconds), executed in: 89.033s (1 minute 29 seconds)
```

```
root@localhost:playground_db> select receipts.id, image_data from receipts inner join receipt_images ON receipt_images.receipt_id = receipts.id
Time: 92.432s (1 minute 32 seconds), executed in: 84.650s (1 minute 24 seconds)
```

And the EXPLAIN ANALYZE results:
```
root@localhost:playground_db> explain analyze select receipts.id, image_data from receipts inner join receipt_images ON receipt_images.receipt_id = receipts.id
+-----------------------------------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                                                  |
|-----------------------------------------------------------------------------------------------------------------------------|
| Hash Join  (cost=3084.00..6645.51 rows=100000 width=22) (actual time=24.782..64.716 rows=100000 loops=1)                    |
|   Hash Cond: (receipt_images.receipt_id = receipts.id)                                                                      |
|   ->  Seq Scan on receipt_images  (cost=0.00..1736.00 rows=100000 width=22) (actual time=0.823..13.888 rows=100000 loops=1) |
|   ->  Hash  (cost=1443.00..1443.00 rows=100000 width=4) (actual time=23.398..23.398 rows=100000 loops=1)                    |
|         Buckets: 131072  Batches: 2  Memory Usage: 2781kB                                                                   |
|         ->  Seq Scan on receipts  (cost=0.00..1443.00 rows=100000 width=4) (actual time=0.007..7.214 rows=100000 loops=1)   |
| Planning Time: 1.894 ms                                                                                                     |
| Execution Time: 67.669 ms                                                                                                   |
+-----------------------------------------------------------------------------------------------------------------------------+
EXPLAIN 8
Time: 0.077s
```

```
root@localhost:playground_db> explain analyze select id, receipt_image from receipt_with_image
+---------------------------------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                                                |
|---------------------------------------------------------------------------------------------------------------------------|
| Seq Scan on receipt_with_image  (cost=0.00..1637.00 rows=100000 width=22) (actual time=0.019..11.245 rows=100000 loops=1) |
| Planning Time: 0.230 ms                                                                                                   |
| Execution Time: 16.547 ms                                                                                                 |
+---------------------------------------------------------------------------------------------------------------------------+
EXPLAIN 3
Time: 0.024s
```

Now the same but for simple selects without images:

```
root@localhost:playground_db> select id from receipts_with_image
Time: 0.051s

root@localhost:playground_db> select id from receipts
Time: 0.044s
```

And the EXPLAIN ANALYZE results:

```
root@localhost:playground_db> explain analyze select id from receipt_with_image;
+--------------------------------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                                               |
|--------------------------------------------------------------------------------------------------------------------------|
| Seq Scan on receipt_with_image  (cost=0.00..1637.00 rows=100000 width=4) (actual time=0.028..15.343 rows=100000 loops=1) |
| Planning Time: 0.356 ms                                                                                                  |
| Execution Time: 20.923 ms                                                                                                |
+--------------------------------------------------------------------------------------------------------------------------+
EXPLAIN 3
Time: 0.030s
```

```
root@localhost:playground_db> explain analyze select id from receipts
+---------------------------------------------------------------------------------------------------------------+
| QUERY PLAN                                                                                                    |
|---------------------------------------------------------------------------------------------------------------|
| Seq Scan on receipts  (cost=0.00..1443.00 rows=100000 width=4) (actual time=0.010..8.392 rows=100000 loops=1) |
| Planning Time: 0.075 ms                                                                                       |
| Execution Time: 12.030 ms                                                                                     |
+---------------------------------------------------------------------------------------------------------------+
EXPLAIN 3
Time: 0.018s
```
