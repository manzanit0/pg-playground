
First we change the public schema to bob:

```terraform
locals {
  database = "playground_db"
  user_1   = "bob"
  user_2   = "miriam"
}

resource "postgresql_schema" "this" {
  name     = "public"
  owner    = local.user_1
  database = local.database
}

```

Plan:

```
Terraform will perform the following actions:

  # postgresql_schema.this will be created
  + resource "postgresql_schema" "this" {
      + database      = "playground_db"
      + drop_cascade  = false
      + id            = (known after apply)
      + if_not_exists = true
      + name          = "public"
      + owner         = "bob"
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Result:

```
root@localhost:playground_db> \dn
+--------+-------+
| Name   | Owner |
|--------+-------|
| public | bob   |
+--------+-------+
SELECT 1
Time: 0.007s
```

Now, updating the owner:

```terraform
resource "postgresql_schema" "this" {
  name     = "public"
  owner    = local.user_2
  database = local.database
}

```

Gives the following plan:

```
Terraform will perform the following actions:

  # postgresql_schema.this will be updated in-place
  ~ resource "postgresql_schema" "this" {
        id            = "playground_db.public"
        name          = "public"
      ~ owner         = "bob" -> "miriam"
        # (3 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Result:

```
root@localhost:playground_db> \dn
+--------+--------+
| Name   | Owner  |
|--------+--------|
| public | miriam |
+--------+--------+
SELECT 1
Time: 0.004s
```

Removing the resource seems like it actually attempts to delete the schema!!

```
Terraform will perform the following actions:

  # postgresql_schema.this will be destroyed
  # (because postgresql_schema.this is not in configuration)
  - resource "postgresql_schema" "this" {
      - database      = "playground_db" -> null
      - drop_cascade  = false -> null
      - id            = "playground_db.public" -> null
      - if_not_exists = true -> null
      - name          = "public" -> null
      - owner         = "miriam" -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

And... confirmed!

```
postgresql_schema.this: Destroying... [id=playground_db.public]
╷
│ Error: Error deleting schema: pq: cannot drop schema public because other objects depend on it
│ 
│ 
╵
```

On the other hand if add _another_ resource without removing the existing `postgresql_schema`:

```terraform
resource "postgresql_schema" "this_2" {
  name     = "public"
  owner    = local.user_1
  database = local.database
}
```

This is the plan

```
Terraform will perform the following actions:

  # postgresql_schema.this_2 will be created
  + resource "postgresql_schema" "this_2" {
      + database      = "playground_db"
      + drop_cascade  = false
      + id            = (known after apply)
      + if_not_exists = true
      + name          = "public"
      + owner         = "bob"
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

And the schema is happily migrated

```
root@localhost:playground_db> \dn
+--------+-------+
| Name   | Owner |
|--------+-------|
| public | bob   |
+--------+-------+
SELECT 1
Time: 0.008s
```

Trying to remove either of the `postgresql_schema` resources spits out the destroy error again. The right way
to go about this would be with the `remove` directive:

```terraform
# NOTE: remove the resource in the same plan; no need to do it in two cycles!
removed {
  from = postgresql_schema.this
  lifecycle {
    destroy = false
  }
}
```

The plan outputs:

```
Terraform will perform the following actions:

 # postgresql_schema.this will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "postgresql_schema" "this" {
        id            = "playground_db.public"
        name          = "public"
        # (4 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
╷
│ Warning: Some objects will no longer be managed by Terraform
│ 
│ If you apply this plan, Terraform will discard its tracking information for the following objects, but it will not delete them:
│  - postgresql_schema.this
│ 
│ After applying this plan, Terraform will no longer manage these objects. You will need to import them into Terraform to manage them again.
```

## Removing default priviledges

```shell
pg-playground/terraform master*​ 4m16s 
❯ pgcli postgresql://root:1234@localhost:5438/playground_db
Server: PostgreSQL 13.16 (Debian 13.16-1.pgdg110+1)
Version: 4.1.0
Home: http://pgcli.com
root@localhost:playground_db> \ddp
+--------+--------+-------+-------------------+
| Owner  | Schema | Type  | Access privileges |
|--------+--------+-------+-------------------|
| miriam | public | table | john=r/miriam     |
+--------+--------+-------+-------------------+
SELECT 1
Time: 0.012s
root@localhost:playground_db>                                                                                                                                              
Goodbye!

pg-playground/terraform master*​ 5s 
❯ terraform apply                                          
postgresql_default_privileges.read_only_tables: Refreshing state... [id=john_playground_db_public_miriam_table]
postgresql_role.my_role: Refreshing state... [id=john]
postgresql_grant.readonly_tables: Refreshing state... [id=john_playground_db_public_table_persons]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # postgresql_default_privileges.read_only_tables will be destroyed
  # (because postgresql_default_privileges.read_only_tables is not in configuration)
  - resource "postgresql_default_privileges" "read_only_tables" {
      - database          = "playground_db" -> null
      - id                = "john_playground_db_public_miriam_table" -> null
      - object_type       = "table" -> null
      - owner             = "miriam" -> null
      - privileges        = [
          - "SELECT",
        ] -> null
      - role              = "john" -> null
      - schema            = "public" -> null
      - with_grant_option = false -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

postgresql_default_privileges.read_only_tables: Destroying... [id=john_playground_db_public_miriam_table]
postgresql_default_privileges.read_only_tables: Destruction complete after 0s

Apply complete! Resources: 0 added, 0 changed, 1 destroyed.

pg-playground/terraform master*​ 
❯ pgcli postgresql://root:1234@localhost:5438/playground_db
Server: PostgreSQL 13.16 (Debian 13.16-1.pgdg110+1)
Version: 4.1.0
Home: http://pgcli.com
root@localhost:playground_db> \dt+ persons
+--------+---------+-------+-------+------------+-------------+
| Schema | Name    | Type  | Owner | Size       | Description |
|--------+---------+-------+-------+------------+-------------|
| public | persons | table | bob   | 8192 bytes | <null>      |
+--------+---------+-------+-------+------------+-------------+
SELECT 1
Time: 0.014s
root@localhost:playground_db> \ddp
+-------+--------+------+-------------------+
| Owner | Schema | Type | Access privileges |
|-------+--------+------+-------------------|
+-------+--------+------+-------------------+
SELECT 0
Time: 0.010s
root@localhost:playground_db>
```
