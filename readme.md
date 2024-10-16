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
