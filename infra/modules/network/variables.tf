variable "name_prefix" {
  description = "Prefix applied to all resource names/tags (keep failoverpoc-* to match the scoped IAM policy)"
  type        = string
  default     = "failoverpoc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread subnets across (3 to match the 3-node AG cluster)"
  type        = number
  default     = 3
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.5/32) — used to scope RDP/SSMS access. Get it from https://checkip.amazonaws.com"
  type        = string
}
