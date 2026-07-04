data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# --- VPC ---

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# --- Public subnets, one per AZ (no NAT — see plan section 0 for the cost rationale) ---

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Security groups ---

# SQL nodes: RDP from admin IP only, unrestricted traffic between cluster
# members (WSFC/AG needs many dynamic RPC ports — scoping each one individually
# is not worth the debugging pain for a POC), and 1433/ProbePort reachable from
# within the VPC (NLB + future API tier live here too).
resource "aws_security_group" "sql_node" {
  name_prefix = "${var.name_prefix}-sql-node-"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-sql-node-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_rdp" {
  security_group_id = aws_security_group.sql_node.id
  description       = "RDP from admin IP"
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_self" {
  security_group_id            = aws_security_group.sql_node.id
  description                  = "WSFC/AG replication + RPC between cluster nodes"
  referenced_security_group_id = aws_security_group.sql_node.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_from_vpc" {
  security_group_id = aws_security_group.sql_node.id
  description       = "SQL (1433) + NLB ProbePort (59999) from within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 1433
  to_port           = 1433
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_probe_from_vpc" {
  security_group_id = aws_security_group.sql_node.id
  description       = "NLB health check ProbePort"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 59999
  to_port           = 59999
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_from_my_ip" {
  security_group_id = aws_security_group.sql_node.id
  description       = "Direct sqlcmd/SSMS access from admin IP for testing"
  cidr_ipv4         = var.my_ip_cidr
  from_port         = 1433
  to_port           = 1433
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "sql_node_all" {
  security_group_id = aws_security_group.sql_node.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ALB in front of the .NET API — only reachable from CloudFront's IP ranges
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from CloudFront only"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ECS Fargate tasks running the .NET API — only reachable from the ALB
resource "aws_security_group" "api" {
  name_prefix = "${var.name_prefix}-api-"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-api-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_from_alb" {
  security_group_id            = aws_security_group.api.id
  description                  = "App traffic from the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "api_all" {
  security_group_id = aws_security_group.api.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "sql_node_from_api" {
  security_group_id            = aws_security_group.sql_node.id
  description                  = "SQL (1433) from the .NET API tasks"
  referenced_security_group_id = aws_security_group.api.id
  from_port                    = 1433
  to_port                      = 1433
  ip_protocol                  = "tcp"
}
