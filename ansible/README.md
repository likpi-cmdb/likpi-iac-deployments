# Likpi CMDB - Ansible Deployment Playbook

This directory contains the official Ansible playbook for provisioning the Likpi CMDB Enterprise architecture on Debian/Ubuntu-based Virtual Machines or bare-metal servers.

## What This Playbook Does
Following the official Likpi Operations Runbook, this automation script executes the following Day 1 provisioning tasks:
* Installs required dependencies (Java 17, Nginx, PostgreSQL 15).
* Creates the dedicated, restricted `likpiadm` service user and groups.
* Provisions the `/opt/likpi/` directory hierarchy with strict permissions.
* Registers and enables the Java Vert.x backend as an auto-restarting `systemd` service.

## Usage Instructions
1. Ensure your target servers are defined in your Ansible `hosts` inventory under the `[cmdb_servers]` group.
2. The playbook will automatically download the latest Likpi binaries directly from the official GitHub releases. No manual file placement is required.
3. Run the deployment playbook:
   ```bash
   ansible-playbook -i hosts playbook.yml
