# Postgres playground

## Connect to the db

```sh
$ pgcli postgresql://bob:1234@localhost:5432/playground_db
```

## Understanding DB ownership

Bob owns the `playground_db` database, not the root user:

```
bob@localhost:playground_db> \l
+---------------+-------+----------+------------+------------+-------------------+
| Name          | Owner | Encoding | Collate    | Ctype      | Access privileges |
|---------------+-------+----------+------------+------------+-------------------|
| playground_db | bob   | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/bob           |
|               |       |          |            |            | bob=CTc/bob       |
| postgres      | root  | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| root          | root  | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| template0     | root  | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |       |          |            |            | root=CTc/root     |
| template1     | root  | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |       |          |            |            | root=CTc/root     |
+---------------+-------+----------+------------+------------+-------------------+
SELECT 5
```

Create a new table:

```
CREATE TABLE persons (person_id int, last_name text);
```

Bob owns the table:

```
bob@localhost:playground_db> \dt+ persons
+--------+---------+-------+-------+------------+-------------+
| Schema | Name    | Type  | Owner | Size       | Description |
|--------+---------+-------+-------+------------+-------------|
| public | persons | table | bob   | 8192 bytes | <null>      |
+--------+---------+-------+-------+------------+-------------+
```

Apparently bob can't create new roles, but root can:

```
bob@localhost:playground_db> CREATE ROLE miriam WITH LOGIN PASSWORD 'jw8s0F4' VALID UNTIL '2025-01-01';
permission denied to create role
```

```
root@localhost:playground_db> CREATE ROLE miriam WITH LOGIN PASSWORD 'jw8s0F4' VALID UNTIL '2025-01-01';
CREATE ROLE
Time: 0.002s
```

Let's create a record, for the sake of understanding if we suffer data losses when changing the schema:

```
bob@localhost:playground_db> INSERT INTO persons (person_id, last_name) VALUES (1, 'foo');
INSERT 0 1
Time: 0.006s
```

Now let's check changing the table ownership:

```
bob@localhost:playground_db> ALTER TABLE persons OWNER TO miriam;
You're about to run a destructive command.
Do you want to proceed? [y/N]: y
Your call!
must be member of role "miriam"
Time: 0.011s
```

Again, bob can't, so root must do it:

```
root@localhost:playground_db> ALTER TABLE persons OWNER TO miriam;
You're about to run a destructive command.
Do you want to proceed? [y/N]: y
Your call!
ALTER TABLE
Time: 0.006s
```

It seems one user can own the DB and another a table in the DB:

```
root@localhost:playground_db> \l
+---------------+-------+----------+------------+------------+-------------------+
| Name          | Owner | Encoding | Collate    | Ctype      | Access privileges |
|---------------+-------+----------+------------+------------+-------------------|
| playground_db | bob   | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/bob           |
|               |       |          |            |            | bob=CTc/bob       |
| postgres      | root  | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| root          | root  | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| template0     | root  | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |       |          |            |            | root=CTc/root     |
| template1     | root  | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |       |          |            |            | root=CTc/root     |
+---------------+-------+----------+------------+------------+-------------------+
SELECT 5
Time: 0.010s

root@localhost:playground_db> \dt+
+--------+---------+-------+--------+-------+-------------+
| Schema | Name    | Type  | Owner  | Size  | Description |
|--------+---------+-------+--------+-------+-------------|
| public | persons | table | miriam | 16 kB | <null>      |
+--------+---------+-------+--------+-------+-------------+
SELECT 1
Time: 0.010s
```

Let's give bob back the table and attempt to change the ownership of the database:

```
root@localhost:playground_db> ALTER TABLE persons OWNER TO bob;
You're about to run a destructive command.
Do you want to proceed? [y/N]: y
Your call!
ALTER TABLE
Time: 0.006s
```

```
root@localhost:playground_db> ALTER DATABASE playground_db OWNER to miriam;
You're about to run a destructive command.
Do you want to proceed? [y/N]: y
Your call!
ALTER DATABASE
Time: 0.007s

root@localhost:playground_db> \l
+---------------+--------+----------+------------+------------+-------------------+
| Name          | Owner  | Encoding | Collate    | Ctype      | Access privileges |
|---------------+--------+----------+------------+------------+-------------------|
| playground_db | miriam | UTF8     | en_US.utf8 | en_US.utf8 | =Tc/miriam        |
|               |        |          |            |            | miriam=CTc/miriam |
| postgres      | root   | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| root          | root   | UTF8     | en_US.utf8 | en_US.utf8 | <null>            |
| template0     | root   | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |        |          |            |            | root=CTc/root     |
| template1     | root   | UTF8     | en_US.utf8 | en_US.utf8 | =c/root           |
|               |        |          |            |            | root=CTc/root     |
+---------------+--------+----------+------------+------------+-------------------+
SELECT 5
Time: 0.010s
```

Changing the ownership of the database doesn't change the ownership of the table:

```
root@localhost:playground_db> \dt+
+--------+---------+-------+-------+-------+-------------+
| Schema | Name    | Type  | Owner | Size  | Description |
|--------+---------+-------+-------+-------+-------------|
| public | persons | table | bob   | 16 kB | <null>      |
+--------+---------+-------+-------+-------+-------------+
SELECT 1
Time: 0.009s
```

This can be easily done with `REASSIGN OWNED`:

```
root@localhost:playground_db> REASSIGN OWNED BY bob TO miriam;
REASSIGN OWNED
Time: 0.007s

root@localhost:playground_db> \dt+
+--------+---------+-------+--------+-------+-------------+
| Schema | Name    | Type  | Owner  | Size  | Description |
|--------+---------+-------+--------+-------+-------------|
| public | persons | table | miriam | 16 kB | <null>      |
+--------+---------+-------+--------+-------+-------------+
SELECT 1
Time: 0.010s
```

Some remarks on `REASSIGN OWNED`:
* Don't run it if the owning user is `postgres`. This would damage the whole database system.
* If you have multiple databases, it will change the owners in all of them.

Resources:
* https://stackoverflow.com/questions/42952018/why-does-postgresql-reassign-role-command-change-template-databases-owner
* https://stackoverflow.com/questions/4313323/how-to-change-owner-of-postgresql-databas

## Transactions

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
