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