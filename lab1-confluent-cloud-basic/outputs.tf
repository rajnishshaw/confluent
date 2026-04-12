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
  value = confluent_api_key.kafka_admin_key.id
  sensitive = true
}

output "topic_name" {
  value = confluent_kafka_topic.sample.topic_name
}