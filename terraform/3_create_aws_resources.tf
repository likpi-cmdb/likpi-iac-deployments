# Fetch the latest Ubuntu 22.04 AMI dynamically for any region
#  Error: reading EC2 AMIs: operation error EC2: DescribeImages, https response error StatusCode: 401, RequestID: 3afbab70-9187-42b2-81fe-3e1bcd0127b8, api error AuthFailure: AWS was not able to validate the provided access credentials
/*data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}*/

# On Apple Silicon (M1/M2/M3) CPU Hypervisor.framework does not alloas nested virtualization: M3 EC2 instances are emulated as metadata only
# -> Error: reading EC2 Instance Type (t3a.medium): empty result
/*resource "aws_instance" "app_host" {
  ami           = data.aws_ami.latest_ubuntu.id
  instance_type = "t3a.medium"

  tags = {
    Name        = "srv-billing-prod-01"
    Environment = var.environment
  }
}*/

# Query AWS to get real-time vCPU count for this instance type
/* data "aws_ec2_instance_type" "app_host_facts" {
  instance_type = aws_instance.app_host.instance_type
} */

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create S3 Bucket storage
# Relation ID:HostedStorage
resource "aws_s3_bucket" "goal" {
  bucket = "project-goal-${random_id.bucket_suffix.hex}-env"
}

# Create DynamoDB database table
resource "aws_dynamodb_table" "goal_users" {
  name           = "users"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "S" # String
  }
}
