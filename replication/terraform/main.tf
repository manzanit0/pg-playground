terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.25.0"
    }
  }
}

provider "postgresql" {
  alias           = "source"
  host            = "localhost"
  port            = 5430
  username        = "postgres"
  password        = "password"
  sslmode         = "disable"
  connect_timeout = 15
}

provider "postgresql" {
  alias           = "target"
  host            = "localhost"
  port            = 5431
  username        = "postgres"
  password        = "password"
  sslmode         = "disable"
  connect_timeout = 15
}

resource "postgresql_database" "test_db_source" {
  name                   = "test_db"
  owner                  = "postgres"
  template               = "template0"
  lc_collate             = "C"
  connection_limit       = -1
  allow_connections      = true
  alter_object_ownership = true

  provider = postgresql.source
}

resource "postgresql_database" "test_db_target" {
  name                   = "test_db"
  owner                  = "postgres"
  template               = "template0"
  lc_collate             = "C"
  connection_limit       = -1
  allow_connections      = true
  alter_object_ownership = true

  provider = postgresql.target
}

resource "postgresql_role" "replication_user" {
  name        = "replication_user"
  password    = "replication_password"
  login       = true
  replication = true

  provider = postgresql.source
}

# Give the replication user access to read the tables it's going to publish,
# both existing and future ones.
resource "postgresql_grant" "public_schema" {
  database    = postgresql_database.test_db_source.name
  role        = postgresql_role.replication_user.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE"]

  depends_on = [
    postgresql_role.replication_user
  ]

  provider = postgresql.source
}

resource "postgresql_grant" "readonly_tables" {
  database    = postgresql_database.test_db_source.name
  role        = postgresql_role.replication_user.name
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT"]
  objects     = [] # Empty means all tables.

  depends_on = [
    postgresql_role.replication_user
  ]

  provider = postgresql.source
}

resource "postgresql_default_privileges" "read_only_tables" {
  role     = postgresql_role.replication_user.name
  database = postgresql_database.test_db_source.name
  schema   = "public"

  owner       = "postgres"
  object_type = "table"
  privileges  = ["SELECT"]

  depends_on = [
    postgresql_grant.readonly_tables
  ]

  provider = postgresql.source
}

resource "postgresql_publication" "source_publication" {
  name       = "source_publication"
  all_tables = true
  database   = postgresql_database.test_db_source.name

  provider = postgresql.source
}

resource "postgresql_subscription" "target_subscription" {
  name         = "target_subscription"
  database     = postgresql_database.test_db_target.name
  publications = [postgresql_publication.source_publication.name]
  conninfo     = "host=pg15 port=5432 dbname=${postgresql_database.test_db_source.name} user=${postgresql_role.replication_user.name} password=${postgresql_role.replication_user.password}"

  provider = postgresql.target
}
