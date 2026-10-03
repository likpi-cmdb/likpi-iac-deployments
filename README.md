# Likpi CMDB - Enterprise IaC Deployments

Welcome to the Infrastructure as Code (IaC) deployment repository for the Likpi CMDB demonstrator. 
This repository provides a local first demo automation modules to test Likpi.

It uses
- Podman via Podman desktop,
- Likpi CMDB,
- a local Cloud simulator: Floci AWS mode,
- and Terraform as first demo.

- Other integrations will be activated later: Ansible, Helm, OpenTofu.

## Repository Structure
* **/.github/workflows:** GitHub Actions pipelines for strict Pre-Merge YAML validation against the Likpi Gatekeeper schema.
* **/ansible:** Playbooks for Day 1 bare-metal/VM provisioning, including Java 17, Nginx, and systemd service registration.
* **/helm:** Kubernetes charts to orchestrate Likpi across Docker containers with StatefulSets for PostgreSQL.
* **/sim-cloud-floci-podman:** Local Cloud simulator
* **/terraform:** AWS/Azure modules to provision cloud infrastructure and dynamically template GitOps-compliant `likpi.yaml` manifests.

## Quick Start
1. Install Podman Desktop
2. Install Likpi CMDB https://www.likpi.com : frontend / backend / db postgresql
3. Install ./sim-cloud-floci-podman/floci-podman.sh
 3.1 chmod u+x ./install_floci_podman.zsh

4. Install Terraform 
5. Configure Terraform

podman machine start
bin % ./floci-podman up aws

AWS — floci on port 4566 - http://localhost:4566/
 export AWS_ENDPOINT_URL=http://localhost:4566
  export AWS_ACCESS_KEY_ID=test
  export AWS_SECRET_ACCESS_KEY=test
  export AWS_DEFAULT_REGION=us-east-1

http://localhost:4566/_floci/ui Floci UI unavailable

Could not start the Floci web console: 
Floci could not reach the container runtime (java.net.BindException: Permission denied). 
Check that the Docker/Podman socket is mounted into the Floci container and accessible — 
on SELinux hosts the socket bind-mount may need relabeling (e.g. ':z') 
or '--security-opt label=disable'.

/etc/floci/init/

https://floci.io/floci/services/config/
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

cd ../../../terraform
chmod u+x 0_start.sh
./0_start_tf_pipeline.sh

brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version


## Open source projects used
* IBM/Red Hat - Podman Desktop
* Floci
 * https://github.com/DawidAdamski/floci-podman/
* IBM Terraform