variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32) — used to scope RDP/SSMS access to the SQL nodes. Get it from https://checkip.amazonaws.com"
  type        = string
}
