resource "confluent_environment" "env" {
  display_name = var.environment_name
}

resource "confluent_kafka_cluster" "basic" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud
  region       = var.region

  basic {}

  environment {
    id = confluent_environment.env.id
  }
}

resource "confluent_service_account" "admin" {
  display_name = var.service_account_name
  description  = "Service account for Terraform-managed Kafka resources"
}

resource "confluent_role_binding" "cluster_admin" {
  principal   = "User:${confluent_service_account.admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.basic.rbac_crn
}

resource "confluent_api_key" "kafka_admin_key" {
  display_name = "kafka-admin-key"
  description  = "Kafka API key owned by Terraform admin service account"

  owner {
    id          = confluent_service_account.admin.id
    api_version = confluent_service_account.admin.api_version
    kind        = confluent_service_account.admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.env.id
    }
  }

  depends_on = [
    confluent_role_binding.cluster_admin
  ]
}

resource "confluent_kafka_topic" "sample" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  topic_name       = var.topic_name
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.basic.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }

  depends_on = [
    confluent_api_key.kafka_admin_key
  ]
}

# ── Schema Registry (data source - auto-provisioned with environment) ────────────
data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.env.id
  }
}

# ── users topic ──────────────────────────────────────────────────────────────
resource "confluent_kafka_topic" "users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }

  topic_name       = var.users_topic_name
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.basic.rest_endpoint

  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }

  depends_on = [confluent_api_key.kafka_admin_key]
}

# ── shared datagen service account ───────────────────────────────────────────
resource "confluent_service_account" "datagen" {
  display_name = "datagen-sa"
  description  = "Service account for datagen connectors"
}

resource "confluent_kafka_acl" "datagen_write_orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = var.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.datagen.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
}

resource "confluent_kafka_acl" "datagen_write_users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = var.users_topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.datagen.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
}

resource "confluent_api_key" "datagen_key" {
  display_name = "datagen-key"
  description  = "Kafka API key for datagen connectors"

  owner {
    id          = confluent_service_account.datagen.id
    api_version = confluent_service_account.datagen.api_version
    kind        = confluent_service_account.datagen.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.basic.id
    api_version = confluent_kafka_cluster.basic.api_version
    kind        = confluent_kafka_cluster.basic.kind

    environment {
      id = confluent_environment.env.id
    }
  }

  depends_on = [
    confluent_kafka_acl.datagen_write_orders,
    confluent_kafka_acl.datagen_write_users
  ]
}

# ── datagen: orders ───────────────────────────────────────────────────────────
resource "confluent_connector" "datagen_orders" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  config_sensitive = {
    "kafka.api.key"    = confluent_api_key.datagen_key.id
    "kafka.api.secret" = confluent_api_key.datagen_key.secret
  }
  config_nonsensitive = {
    "connector.class"    = "DatagenSource"
    "name"               = "datagen-orders"
    "kafka.topic"        = var.topic_name
    "output.data.format" = "AVRO"
    "quickstart"         = "ORDERS"
    "tasks.max"          = "1"
    "max.interval"       = "1000"
  }
  depends_on = [
    confluent_kafka_topic.sample,
    confluent_api_key.datagen_key
  ]
}

# ── datagen: users ────────────────────────────────────────────────────────────
resource "confluent_connector" "datagen_users" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  config_sensitive = {
    "kafka.api.key"    = confluent_api_key.datagen_key.id
    "kafka.api.secret" = confluent_api_key.datagen_key.secret
  }
  config_nonsensitive = {
    "connector.class"    = "DatagenSource"
    "name"               = "datagen-users"
    "kafka.topic"        = var.users_topic_name
    "output.data.format" = "AVRO"
    "quickstart"         = "USERS"
    "tasks.max"          = "1"
    "max.interval"       = "1000"
  }
  depends_on = [
    confluent_kafka_topic.users,
    confluent_api_key.datagen_key
  ]
}

# ── Flink output topics ───────────────────────────────────────────────────────
resource "confluent_kafka_topic" "high_value_orders" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name       = "high-value-orders"
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
  depends_on = [confluent_api_key.kafka_admin_key]
}

resource "confluent_kafka_topic" "orders_with_users" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name       = "orders-with-users"
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
  depends_on = [confluent_api_key.kafka_admin_key]
}

resource "confluent_kafka_topic" "orders_per_region" {
  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  topic_name       = "orders-per-region"
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
  depends_on = [confluent_api_key.kafka_admin_key]
}

# ── Flink compute pool ────────────────────────────────────────────────────────
resource "confluent_flink_compute_pool" "main" {
  display_name = "flink-pool"
  cloud        = var.cloud
  region       = var.region
  max_cfu      = 5

  environment {
    id = confluent_environment.env.id
  }
}

data "confluent_flink_region" "main" {
  cloud  = var.cloud
  region = var.region
}

# ── Flink service account + API key ──────────────────────────────────────────
resource "confluent_service_account" "flink" {
  display_name = "flink-sa"
  description  = "Service account for Flink statements"
}

resource "confluent_role_binding" "flink_developer" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.env.resource_name
}

resource "confluent_api_key" "flink_key" {
  display_name = "flink-api-key"
  description  = "API key for Flink statements"

  owner {
    id          = confluent_service_account.flink.id
    api_version = confluent_service_account.flink.api_version
    kind        = confluent_service_account.flink.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.main.id
    api_version = data.confluent_flink_region.main.api_version
    kind        = data.confluent_flink_region.main.kind

    environment {
      id = confluent_environment.env.id
    }
  }

  depends_on = [confluent_role_binding.flink_developer]
}

# ── Flink SA ACLs: read inputs, write outputs ─────────────────────────────────
locals {
  flink_read_topics  = [var.topic_name, var.users_topic_name, "orders-with-users"]
  flink_write_topics = ["high-value-orders", "orders-with-users", "orders-per-region"]
}

resource "confluent_kafka_acl" "flink_read" {
  for_each = toset(local.flink_read_topics)

  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = each.value
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
}

resource "confluent_kafka_acl" "flink_write" {
  for_each = toset(local.flink_write_topics)

  kafka_cluster {
    id = confluent_kafka_cluster.basic.id
  }
  resource_type = "TOPIC"
  resource_name = each.value
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.basic.rest_endpoint
  credentials {
    key    = confluent_api_key.kafka_admin_key.id
    secret = confluent_api_key.kafka_admin_key.secret
  }
}

# ── Flink statement 1: filter high-value orders ───────────────────────────────
resource "confluent_flink_statement" "create_high_value_orders" {
  organization { id = data.confluent_organization.main.id }
  environment  { id = confluent_environment.env.id }
  compute_pool { id = confluent_flink_compute_pool.main.id }
  principal    { id = confluent_service_account.flink.id }

  rest_endpoint = data.confluent_flink_region.main.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_key.id
    secret = confluent_api_key.flink_key.secret
  }

  statement_name = "create-high-value-orders"
  statement      = <<-SQL
    CREATE TABLE IF NOT EXISTS `high-value-orders` WITH (
      'connector'    = 'confluent',
      'value.format' = 'avro-registry'
    ) AS SELECT orderid, itemid, orderunits, orderunits * 10.0 AS amount
    FROM `${var.topic_name}`
    WHERE orderunits > 5;
  SQL

  properties = {
    "sql.current-catalog"  = confluent_environment.env.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }

  depends_on = [
    confluent_api_key.flink_key,
    confluent_kafka_topic.high_value_orders,
    confluent_kafka_acl.flink_read,
    confluent_kafka_acl.flink_write,
    confluent_connector.datagen_orders,
    confluent_connector.datagen_users,
    data.confluent_schema_registry_cluster.sr
  ]
}

# ── Flink statement 2: enrich orders with users ──────────────────────────────
resource "confluent_flink_statement" "create_orders_with_users" {
  organization { id = data.confluent_organization.main.id }
  environment  { id = confluent_environment.env.id }
  compute_pool { id = confluent_flink_compute_pool.main.id }
  principal    { id = confluent_service_account.flink.id }

  rest_endpoint = data.confluent_flink_region.main.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_key.id
    secret = confluent_api_key.flink_key.secret
  }

  statement_name = "create-orders-with-users"
  statement      = <<-SQL
    CREATE TABLE IF NOT EXISTS `orders-with-users` WITH (
      'connector'    = 'confluent',
      'value.format' = 'avro-registry'
    ) AS SELECT o.orderid, o.itemid, o.orderunits, u.userid, u.regionid
    FROM `${var.topic_name}` o
    JOIN `${var.users_topic_name}` u
      ON o.orderid = u.userid;
  SQL

  properties = {
    "sql.current-catalog"  = confluent_environment.env.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }

  depends_on = [
    confluent_flink_statement.create_high_value_orders,
    confluent_kafka_topic.orders_with_users
  ]
}

# ── Flink statement 3: count orders per region ───────────────────────────────
resource "confluent_flink_statement" "create_orders_per_region" {
  organization { id = data.confluent_organization.main.id }
  environment  { id = confluent_environment.env.id }
  compute_pool { id = confluent_flink_compute_pool.main.id }
  principal    { id = confluent_service_account.flink.id }

  rest_endpoint = data.confluent_flink_region.main.rest_endpoint
  credentials {
    key    = confluent_api_key.flink_key.id
    secret = confluent_api_key.flink_key.secret
  }

  statement_name = "create-orders-per-region"
  statement      = <<-SQL
    CREATE TABLE IF NOT EXISTS `orders-per-region` WITH (
      'connector'    = 'confluent',
      'value.format' = 'avro-registry'
    ) AS SELECT regionid, COUNT(*) AS order_count
    FROM `${var.users_topic_name}`
    GROUP BY regionid;
  SQL

  properties = {
    "sql.current-catalog"  = confluent_environment.env.display_name
    "sql.current-database" = confluent_kafka_cluster.basic.display_name
  }

  depends_on = [
    confluent_flink_statement.create_orders_with_users,
    confluent_kafka_topic.orders_per_region
  ]
}

# ── data source: org ID (needed for Flink statements) ─────────────────────────
data "confluent_organization" "main" {}