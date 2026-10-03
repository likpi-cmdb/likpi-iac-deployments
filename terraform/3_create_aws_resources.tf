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
  instance_type = "t3a.medium"

  tags = {
    Name        = "srv-billing-prod-01"
    Environment = var.environment
  }
}

# Query AWS to get real-time vCPU count for this instance type
data "aws_ec2_instance_type" "app_host_facts" {
  instance_type = aws_instance.app_host.instance_type
}
