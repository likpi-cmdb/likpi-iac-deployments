variable "app_name" {
  description = "The name of the application being deployed"
  default     = "app-billing-backend"
}

resource "aws_instance" "app_host" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.large"
  tags = {
    Name        = "srv-billing-prod-01"
    Environment = "PROD"
  }
}

# Dynamically fetch AWS instance hardware facts
data "aws_ec2_instance_type" "app_host_facts" {
  instance_type = aws_instance.app_host.instance_type
}

resource "local_file" "likpi_manifest" {
  content = templatefile("${path.module}/likpi.yaml.tftpl", {
    vm_name       = aws_instance.app_host.tags["Name"]
    vm_id         = aws_instance.app_host.id
    environment   = aws_instance.app_host.tags["Environment"]
    ip_address    = aws_instance.app_host.private_ip
    cpu_count     = tostring(data.aws_ec2_instance_type.app_host_facts.default_vcpus)
    app_name      = var.app_name
  })
  filename = "${path.module}/likpi.yaml"
}
