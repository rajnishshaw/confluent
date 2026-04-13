variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret"
  type        = string
  sensitive   = true
}

variable "environment_name" {
  description = "Confluent Cloud environment name"
  type        = string
  default     = "Development"
}

variable "cluster_name" {
  description = "Kafka cluster name"
  type        = string
  default     = "basic-kafka-cluster"
}

variable "cloud" {
  description = "Cloud provider"
  type        = string
  default     = "AWS"
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-east-2"
}

variable "availability" {
  description = "Cluster availability"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "service_account_name" {
  description = "Service account name"
  type        = string
  default     = "tf-admin"
}

variable "topic_name" {
  description = "Orders topic name"
  type        = string
  default     = "orders"
}

variable "users_topic_name" {
  description = "Users topic name"
  type        = string
  default     = "users"
}

variable "topic_partitions" {
  description = "Partition count"
  type        = number
  default     = 1
}