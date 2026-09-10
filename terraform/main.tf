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

# Example AWS EC2 Resource
resource "aws_instance" "app_host" {
  ami           = "ami-0c55b159cbfafe1f0"
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

# Generate the Likpi manifest matching schema.json
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
