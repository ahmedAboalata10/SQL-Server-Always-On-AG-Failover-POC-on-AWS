module "network" {
  source = "../../modules/network"

  my_ip_cidr = var.my_ip_cidr
}

resource "random_password" "sql_sa" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  # SQL Server disallows some special chars in complexity-checked passwords; keep to a safe set
  override_special = "!#%^&*()-_=+"
}

module "sql_nodes" {
  source = "../../modules/sql-nodes"

  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_id  = module.network.sql_node_security_group_id
  sa_password        = random_password.sql_sa.result
}
