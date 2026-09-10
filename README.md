# Likpi CMDB - Enterprise IaC Deployments

Welcome to the official Infrastructure as Code (IaC) deployment repository for the Likpi CMDB. This repository provides enterprise-grade automation modules to provision, configure, and synchronize your Likpi environment.

## Repository Structure
* **/terraform:** AWS/Azure modules to provision cloud infrastructure and dynamically template GitOps-compliant `likpi.yaml` manifests.
* **/ansible:** Playbooks for Day 1 bare-metal/VM provisioning, including Java 17, Nginx, and systemd service registration.
* **/helm:** Kubernetes charts to orchestrate Likpi across Docker containers with StatefulSets for PostgreSQL.
* **/.github/workflows:** GitHub Actions pipelines for strict Pre-Merge YAML validation against the Likpi Gatekeeper schema.

## Quick Start
Navigate to the tool of your choice above and follow the dedicated `README.md` instructions in each folder.
