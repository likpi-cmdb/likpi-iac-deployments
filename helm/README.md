# Likpi CMDB - Kubernetes Helm Chart

This directory contains the official Helm chart to orchestrate the Likpi CMDB on Kubernetes. 

## Architecture
This chart provisions:
* A `StatefulSet` and Headless Service for PostgreSQL 15, ensuring persistent 10Gi storage.
* A Highly Available (HA) `Deployment` for the Java Vert.x backend (defaulting to 3 replicas).
* Dedicated ClusterIP Services for internal routing.

## Usage Instructions
1. Navigate into this directory.
2. Override the default database credentials in `likpi-cmdb/values.yaml` for production security.
3. Install the chart into your cluster:
   ```bash
   helm install my-likpi-release ./likpi-cmdb
