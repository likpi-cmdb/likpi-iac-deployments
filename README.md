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
* 3.1 chmod u+x ./install_floci_podman.zsh
* 3.2 Launch Podman: podman machine start
* 3.3 Launch Floci: cd ./sim-cloud-floci-podman/floci-podman-0.1.1/bin && ./floci-podman up aws

Expected result:
* AWS — floci on port 4566 - http://localhost:4566/

4. Install Terraform

on macos:
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version

5. Test the Terraform IaC pipeline with bash script

```bash
cd ../../../0_start_tf_pipeline.sh
chmod u+x 0_start.sh
./0_start_tf_pipeline.sh
```

## Open source projects used
* IBM/Red Hat - Podman Desktop
* Floci
 * + https://github.com/DawidAdamski/floci-podman/
* IBM Terraform