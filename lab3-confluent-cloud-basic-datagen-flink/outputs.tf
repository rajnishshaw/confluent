output "environment_id" {
  value = confluent_environment.env.id
}

output "kafka_cluster_id" {
  value = confluent_kafka_cluster.basic.id
}

output "kafka_rest_endpoint" {
  value = confluent_kafka_cluster.basic.rest_endpoint
}

output "service_account_id" {
  value = confluent_service_account.admin.id
}

output "kafka_api_key_id" {
  value     = confluent_api_key.kafka_admin_key.id
  sensitive = true
}

# ── input topics ──────────────────────────────────────────────────────────────
output "topic_orders" {
  value = confluent_kafka_topic.sample.topic_name
}

output "topic_users" {
  value = confluent_kafka_topic.users.topic_name
}

# ── flink output topics ───────────────────────────────────────────────────────
output "topic_high_value_orders" {
  value = confluent_kafka_topic.high_value_orders.topic_name
}

output "topic_orders_with_users" {
  value = confluent_kafka_topic.orders_with_users.topic_name
}

output "topic_orders_per_region" {
  value = confluent_kafka_topic.orders_per_region.topic_name
}

# ── connectors ────────────────────────────────────────────────────────────────
output "datagen_orders_connector_id" {
  value = confluent_connector.datagen_orders.id
}

output "datagen_users_connector_id" {
  value = confluent_connector.datagen_users.id
}

# ── flink ─────────────────────────────────────────────────────────────────────
output "flink_compute_pool_id" {
  value = confluent_flink_compute_pool.main.id
}
