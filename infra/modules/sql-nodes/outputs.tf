output "instance_ids" {
  value = aws_instance.sql_node[*].id
}

output "private_ips" {
  value = aws_instance.sql_node[*].private_ip
}

output "public_ips" {
  value = aws_instance.sql_node[*].public_ip
}

output "node_names" {
  value = var.node_names
}
