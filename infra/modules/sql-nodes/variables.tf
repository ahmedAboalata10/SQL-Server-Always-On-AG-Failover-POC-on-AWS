variable "name_prefix" {
  description = "Prefix applied to all resource names/tags"
  type        = string
  default     = "failoverpoc"
}

variable "instance_type" {
  description = "EC2 instance type for the SQL nodes (t3.large to start; bump to t3.xlarge if memory pressure shows up under load test)"
  type        = string
  default     = "t3.large"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size per node (gp3)"
  type        = number
  default     = 60
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "One subnet per node — list must have exactly 3 entries, one per AZ"
  type        = list(string)
}

variable "security_group_id" {
  description = "sql_node security group ID from the network module"
  type        = string
}

variable "node_names" {
  description = "Computer names for the 3 nodes, used for hostname + hosts-file entries (no AD DNS available)"
  type        = list(string)
  default     = ["sqlnode1", "sqlnode2", "sqlnode3"]
}

variable "node_private_ips" {
  description = "Static private IPs, one per node, matching node_names order — needed for hosts-file entries since there's no AD DNS"
  type        = list(string)
  default     = ["10.0.1.10", "10.0.2.10", "10.0.3.10"]
}

variable "sa_password" {
  description = "SQL Server sa password — stored in SSM Parameter Store (SecureString), never in state-visible plaintext resources"
  type        = string
  sensitive   = true
}
