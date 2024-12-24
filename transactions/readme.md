# Transactions

> [!IMPORTANT]
> Use the root `docker-compose.yaml` for this.

Apparently if an error ocurrs in any of the DMLs during a transaction, the
transaction is aborted: the commit will act as a rollback.

```
root@localhost:playground_db> CREATE TABLE queue ( id SERIAL PRIMARY KEY, error text );
CREATE TABLE
Time: 0.024s

root@localhost:playground_db> begin
BEGIN
Time: 0.003s

root@localhost:playground_db> insert into queue (error) values('foo')
INSERT 0 1
Time: 0.007s

root@localhost:playground_db> select wrong_column from queue
column "wrong_column" does not exist
LINE 1: select wrong_column from queue
               ^
Time: 0.006s

root@localhost:playground_db> insert into queue (error) values('bar')
current transaction is aborted, commands ignored until end of transaction block
Time: 0.004s

root@localhost:playground_db> commit
ROLLBACK
Time: 0.007s

root@localhost:playground_db> select * from queue
+----+-------+
| id | error |
|----+-------|
+----+-------+
SELECT 0
Time: 0.008s
```

If we want to keep some of the operations in the transaction before the error
ocurrs, a workaround this could be to use the `SAVEPOINT` command:

```
root@localhost:playground_db> begin
BEGIN
Time: 0.003s

root@localhost:playground_db> insert into queue (error) values('foo')
INSERT 0 1
Time: 0.004s

root@localhost:playground_db> savepoint first_element_done
SAVEPOINT
Time: 0.020s

root@localhost:playground_db> select wrong_column from queue
column "wrong_column" does not exist
LINE 1: select wrong_column from queue
               ^
Time: 0.010s

root@localhost:playground_db> rollback to first_element_done
ROLLBACK
Time: 0.002s

root@localhost:playground_db> commit
COMMIT
Time: 0.005s

root@localhost:playground_db> select * from queue
+----+-------+
| id | error |
|----+-------|
| 5  | foo   |
+----+-------+
SELECT 1
Time: 0.003s
```

Alternatively a `BEGIN`/`EXCEPTION` block could be used:

```
root@localhost:playground_db> begin
BEGIN
Time: 0.001s

root@localhost:playground_db> DO LANGUAGE plpgsql
 $$
 BEGIN
     INSERT INTO queue (wrong_column) VALUES ('');
 EXCEPTION
     WHEN OTHERS THEN
         INSERT INTO queue (error) VALUES ('caught');
 END;
 $$

DO
Time: 0.005s

root@localhost:playground_db> commit
COMMIT
Time: 0.003s

root@localhost:playground_db> select * from queue
+----+--------+
| id | error  |
|----+--------|
| 8  | caught |
+----+--------+
SELECT 1
Time: 0.006s
```
