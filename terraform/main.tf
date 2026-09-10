# 1. Create the Cloud Infrastructure
resource "aws_instance" "app_server" {
  ami           = "ami-12345678"
  instance_type = "t3.large"

  tags = {
    Name        = "srv-billing-prod-01"
    Environment = "Production"
  }
}

# 2. Generate the Likpi GitOps Manifest
resource "local_file" "likpi_manifest" {
  content = templatefile("${path.module}/likpi.yaml.tftpl", {
    instance_id   = aws_instance.app_server.id
    instance_name = aws_instance.app_server.tags["Name"]
    environment   = aws_instance.app_server.tags["Environment"]
  })
  filename = "${path.module}/likpi.yaml"
}
