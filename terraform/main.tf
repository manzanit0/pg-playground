terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.23.0"
    }
  }
}

locals {
  database = "playground_db"
  user_1   = "bob"
  user_2   = "miriam"
  table    = "persons"
}

provider "postgresql" {
  host            = "localhost"
  port            = 5432
  database        = local.database
  username        = "root"
  password        = "1234"
  sslmode         = "disable"
  connect_timeout = 15
}

# Let's create a new role named "john".
resource "postgresql_role" "my_role" {
  name     = "john"
  login    = true
  password = "6789"
}

# We'll grant "john" SELECT access to the "persons" table in the "public" schema.
resource "postgresql_grant" "readonly_tables" {
  database    = local.database
  role        = postgresql_role.my_role.name
  schema      = "public"
  object_type = "table"
  objects     = [local.table]
  privileges  = ["SELECT"]

  depends_on = [
    postgresql_role.my_role
  ]
}

# Now we'll grant some default priviledges for all future tables.
resource "postgresql_default_privileges" "read_only_tables" {
  role     = postgresql_role.my_role.name
  database = local.database
  schema   = "public"

  owner       = local.user_2
  object_type = "table"
  privileges  = ["SELECT"]

  depends_on = [
    postgresql_grant.readonly_tables
  ]
}
