data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  hosts_entries = join("\n", [for i in range(length(var.node_names)) : "${var.node_private_ips[i]} ${var.node_names[i]}"])
}

# --- IAM role for SSM (Session Manager + Run Command) — no RDP-only dependency for admin access ---

resource "aws_iam_role" "sql_node" {
  name = "${var.name_prefix}-sql-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.sql_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sql_node" {
  name = "${var.name_prefix}-sql-node-profile"
  role = aws_iam_role.sql_node.name
}

# --- Secrets used by later bootstrap phases, stored now so they exist before Phase 3 scripts run ---

resource "aws_ssm_parameter" "sa_password" {
  name  = "/${var.name_prefix}/sql/sa-password"
  type  = "SecureString"
  value = var.sa_password
}

# --- The 3 SQL nodes ---

resource "aws_instance" "sql_node" {
  count = length(var.node_names)

  ami                    = data.aws_ami.windows_2022.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index]
  private_ip             = var.node_private_ips[count.index]
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.sql_node.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
  }

  user_data = templatefile("${path.module}/templates/bootstrap.ps1.tpl", {
    node_name     = var.node_names[count.index]
    hosts_entries = local.hosts_entries
  })

  tags = {
    Name = "${var.name_prefix}-${var.node_names[count.index]}"
  }
}
