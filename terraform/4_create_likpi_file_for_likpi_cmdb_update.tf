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