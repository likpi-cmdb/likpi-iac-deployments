variable "environment" {
  type        = string
  description = "Target deployment environment"
  default     = "PROD"
}

variable "app_name" {
  type        = string
  description = "Application name in CMDB"
  default     = "app-billing-backend"
}

variable "app_id" {
  type        = string
  description = "Unique Identifier for the application"
  default     = "APP-BILLING-EU-01"
}

variable "db_cluster_name" {
  type        = string
  description = "Target Database CI name"
  default     = "db-postgres-prod"
}

# Fetch the latest Ubuntu 22.04 AMI dynamically for any region
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "app_host" {
  ami           = data.aws_ami.latest_ubuntu.id
  instance_type = "t3.large"

  tags = {
    Name        = "srv-billing-prod-01"
    Environment = var.environment
  }
}

# Query AWS to get real-time vCPU count for this instance type
data "aws_ec2_instance_type" "app_host_facts" {
  instance_type = aws_instance.app_host.instance_type
}

# Generate the Likpi manifest matching the Gatekeeper schema
resource "local_file" "likpi_manifest" {
  content = templatefile("${path.module}/likpi.yaml.tftpl", {
    vm_name         = aws_instance.app_host.tags["Name"]
    vm_id           = aws_instance.app_host.id
    environment     = aws_instance.app_host.tags["Environment"]
    ip_address      = aws_instance.app_host.private_ip
    cpu_count       = tostring(data.aws_ec2_instance_type.app_host_facts.default_vcpus)
    app_name        = var.app_name
    app_id          = var.app_id
    db_cluster_name = var.db_cluster_name
  })
  filename = "${path.module}/likpi.yaml"
}
