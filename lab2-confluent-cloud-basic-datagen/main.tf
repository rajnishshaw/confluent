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

resource "confluent_service_account" "datagen" {
  display_name = "datagen-orders-sa"
  description  = "Service account for orders datagen connector"
}

resource "confluent_kafka_acl" "datagen_producer" {
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

resource "confluent_api_key" "datagen_key" {
  display_name = "datagen-orders-key"
  description  = "Kafka API key for orders datagen connector"

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

  depends_on = [confluent_kafka_acl.datagen_producer]
}

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
    "connector.class"          = "DatagenSource"
    "name"                     = "datagen-orders"
    "kafka.topic"              = var.topic_name
    "output.data.format"       = "JSON"
    "quickstart"               = "ORDERS"
    "tasks.max"                = "1"
    "max.interval"             = "1000"
  }

  depends_on = [
    confluent_kafka_topic.sample,
    confluent_api_key.datagen_key
  ]
}