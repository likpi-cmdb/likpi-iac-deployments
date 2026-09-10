# Likpi CMDB - Terraform GitOps Integration

This directory contains enterprise-grade examples demonstrating how to automatically generate Likpi CMDB GitOps manifests (`likpi.yaml`) directly from your Terraform state.

## Why Use This Approach?
Manual CMDB updates inevitably lead to stale data. By leveraging Terraform's native `templatefile()` function, you can ensure your CMDB perfectly and automatically reflects your live cloud environment.

## How It Works
* **Provision Infrastructure:** Terraform builds your resources (e.g., AWS EC2 instances, Azure VMs, or VPCs).
* **Extract Metadata:** Terraform captures real-time data, such as dynamically generated Instance IDs and resource tags.
* **Template Generation:** Using the `local_file` resource, Terraform injects this live data into the `likpi.yaml.tftpl` template.
* **GitOps Sync:** A schema-compliant `likpi.yaml` file is generated locally. Once committed to your repository, the Likpi webhook engine ingests, validates, and merges the new topology automatically.

## Usage Instructions
1. Copy the `main.tf` and `likpi.yaml.tftpl` files into your working Terraform directory.
2. Modify the `aws_instance` resource in `main.tf` to match your actual cloud provider and resource requirements.
3. Run `terraform init` to initialize the provider.
4. Run `terraform apply` to provision the server and generate the manifest.
5. Commit the resulting `likpi.yaml` file to your Git repository to trigger the Likpi CMDB synchronization.
