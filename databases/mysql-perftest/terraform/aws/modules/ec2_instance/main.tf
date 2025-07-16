locals {
  rendered_user_data = var.user_data_template != null ? templatefile(var.user_data_template, var.user_data_vars) : null
}

resource "aws_instance" "this" {
  count                  = var.instance_count
  ami                    = var.ami_id
  instance_type          = var.machine_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
#   iam_instance_profile   = var.iam_instance_profile
  associate_public_ip_address = false

  metadata_options { http_tokens = "required" }  # IMDSv2 hard-enforced

  # ─── Root volume ──────────────────────────────────────────────
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    iops                  = var.root_volume_type == "gp3" ? var.root_volume_iops : null
    throughput            = var.root_volume_type == "gp3" ? var.root_volume_throughput : null
    encrypted             = true
    delete_on_termination = true
  }

  # ─── Optional single data disk ────────────────────────────────
  dynamic "ebs_block_device" {
    for_each = var.use_data_disk ? [1] : []

    content {
      device_name           = "/dev/sdb"                       # adjust if AMI is NVMe
      volume_type           = var.data_volume_type
      volume_size           = var.data_volume_size
      iops                  = var.data_volume_type == "gp3" ? var.data_volume_iops : null
      throughput            = var.data_volume_type == "gp3" ? var.data_volume_throughput : null
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring       = true
  user_data_base64 = local.rendered_user_data != null ? base64encode(local.rendered_user_data) : null

  tags = {
      Name  = var.instance_count > 1 ? "${var.name_prefix}-${count.index}" : var.name_prefix
      Owner = "terraform"
    }
}

output "name"        { value = aws_instance.this[*].tags["Name"] }
output "private_ip"  { value = aws_instance.this[*].private_ip   }
 