output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "availability_zones" {
  value = module.network.availability_zones
}

output "sql_node_security_group_id" {
  value = module.network.sql_node_security_group_id
}

output "alb_security_group_id" {
  value = module.network.alb_security_group_id
}

output "api_security_group_id" {
  value = module.network.api_security_group_id
}
