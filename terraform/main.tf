resource "aws_instance" "app_host" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.large"

  tags = {
    Name        = "srv-billing-prod-01"
    Environment = "PROD"
  }
}

resource "local_file" "likpi_manifest" {
  content = templatefile("${path.module}/likpi.yaml.tftpl", {
    vm_name         = aws_instance.app_host.tags["Name"]
    vm_id           = aws_instance.app_host.id
    environment     = aws_instance.app_host.tags["Environment"]
    ip_address      = aws_instance.app_host.private_ip
    cpu_count       = "4"
    app_name        = "app-billing-backend"
    app_id          = "APP-BILLING-01"
    db_cluster_name = "db-postgres-prod"
  })
  filename = "${path.module}/likpi.yaml"
}
