# Generate the Likpi manifest matching the Gatekeeper schema
resource "local_file" "likpi_manifest_s3" {
  content = templatefile("${path.module}/likpi_templates/aws_s3.yaml.tftpl", {
    s3_name         = aws_s3_bucket.goal.id
    s3_id           = aws_s3_bucket.goal.id
    environment     = var.tags["Environment"]
    app_name        = var.app_name
    app_id          = var.app_id
  })
  filename = "${path.module}/upload/likpi_s3.yaml"
}

resource "local_file" "likpi_manifest_dynamodb_table" {
  content = templatefile("${path.module}/likpi_templates/aws_dynamodb_table.yaml.tftpl", {
    dynamodb_table_name = aws_dynamodb_table.goal_users.id
    dynamodb_table_id   = aws_dynamodb_table.goal_users.id
    environment     = var.tags["Environment"]
    billing_mode    = aws_dynamodb_table.goal_users.billing_mode
    app_name        = var.app_name
    app_id          = var.app_id
  })
  filename = "${path.module}/upload/dynamodb_table.yaml"
}

/*resource "local_file" "likpi_manifest" {
  content = templatefile("${path.module}/likpi_templates/aws_ec2.yaml.tftpl", {
    vm_name         = aws_instance.app_host.name
    vm_id           = aws_instance.app_host.id
    environment     = var.tags["Environment"]
    ip_address      = aws_instance.app_host.private_ip
    cpu_count       = tostring(data.aws_ec2_instance_type.app_host_facts.default_vcpus)
    app_name        = var.app_name
    app_id          = var.app_id
    db_cluster_name = var.db_cluster_name
  })
  filename = "${path.module}/upload/likpi_ec2.yaml"
}*/