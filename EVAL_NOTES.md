# Remarks
* R1 Give an idea of requirements from start
1. disks/ram/ hostings
2. cloud AWS account or local simulator
3. github workflow usage

* R2 Give a clue on the install process in correct order
1. /helm likpi ITIL CMDB: Backend app + Database with Helm for K8s
1.1 where are the images:   backend: "likpi/cmdb-backend:latest"
  frontend: "likpi/cmdb-frontend:latest"
2. /ansible likpi
3. .github/workflows/valdiate-cmdb.yml on pull_request
3.1. configure: const cmdbUrl = process.env.LIKPI_CMDB_URL || 'https://cmdb.yourdomain.com';
4. /terraform - test the DevOps to ITIL CMDB integration
4.1 likpi.yaml.tftpl is the template file for CMDB data of the AWS resources created

* R3 Give all the tooling to install
1. Docker / Podman / Podman desktop https://podman-desktop.io/ / Kubernnetes
2. Ansible https://docs.ansible.com/
3. Terraform

# Technology version support / what will be needed

Ansible
Teraform
K8s

DB 10G Postgresql v15

Java
NodeJS

https://floci.io/floci/getting-started/terraform/?h=terraform
https://github.com/DawidAdamski/floci-podman/tree/main
https://github.com/DawidAdamski/homebrew-floci-podman
https://github.com/DawidAdamski/homebrew-floci-podman/blob/main/Formula/floci-podman.rb

    backend_download_url: "https://github.com/likpi-cmdb/likpi-iac-deployments/releases/download/v1.0.0/cmdb-app-latest-fat.jar"
    frontend_download_url: "https://github.com/likpi-cmdb/likpi-iac-deployments/releases/download/v1.0.0/cmdb-frontend-build.zip"
- https://github.com/likpi-cmdb/likpi-iac-deployments/releases Empty for me

Ny test env: 
  local macos 26 with podman desktop and https://github.com/floci-io/floci Light, fluffy, and always free - The AWS Local Emulator alternative

# Performances improvements
1. on .github/workflows/valdiate-cmdb.yml on pull_request
 runs-on: ubuntu-latest -> use alpine, never use latest, pin versions

# Terraform
1. The AWS provider section is missing
ex: https://github.com/open-metadata/terraform-aws-openmetadata/blob/main/examples/complete/versions.tf
2. i recommand to create a variables.tf file
3. extract resource "local_file" "likpi_manifest" { to a new file likpi_manifest.tf or create_cmdb_data_records.tf
4. rename likpi.yaml.tftpl to cmdb_data_records.yaml.tftpl

# Sovereign
github -> https://codeberg.org/

llll

n8n.webessentiel.fr
Name:	n8n.webessentiel.fr
Address: 188.114.96.2
Name:	n8n.webessentiel.fr
Address: 188.114.97.2

Blocage d’une requête multiorigine (Cross-Origin Request) : 
la politique « Same Origin » ne permet pas de consulter la ressource distante située 
sur https://n8n.webessentiel.fr/webhook/likpi-cmdb-download. 
Raison : échec de la requête CORS. Code d’état : (null). 2


FLOCI
<Error>
<Code>NoSuchBucket</Code>
<Message>The specified bucket does not exist.</Message>
<RequestId>XXXXXXXXXXXX</RequestId>
</Error>
https://medium.com/@dileeprithvi/running-floci-on-podman-macos-fixing-could-not-reach-the-container-runtime-5c2b53b7f4af
https://github.com/floci-io/floci/issues/1517

podman network create floci-net 2>/dev/null
podman run -d --name floci \
  --privileged \
  --network floci-net \
  --userns=keep-id:uid=1000,gid=1000 \
  -p 127.0.0.1:4566:4566 \
  -v "${MY_PWD}/sim-cloud-floci-podman/floci-data:/app/data:Z" \
  -v "$SOCKET:/var/run/docker.sock:z" \
  -e FLOCI_STORAGE_MODE=persistent \
  -e FLOCI_STORAGE_PERSISTENT_PATH=/app/data \
  -e FLOCI_HOSTNAME=floci \
  -e FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=floci-net \
  -e FLOCI_RUNTIME_API_HOST=floci \
  -e FLOCI_SERVICES_UI_IN_PLACE=true \
  -e FLOCI_SERVICES_DNS_PORT=5353 \
  -e DISABLE_WEB_UI=1 \
  -e DOCKER_CMD=podman \
  --security-opt label=disable \
  floci/floci:latest

Sur les processeurs Apple Silicon (M1/M2/M3), macOS applique des restrictions matérielles strictes via l'Hypervisor.framework qui interdisent ou compliquent fortement la double virtualisation (lancer des conteneurs "Docker dans Docker" ou imbriqués à l'intérieur de la VM Podman).
Puisque la virtualisation imbriquée est bloquée par l'architecture de votre puce M2, le message EC2 instances are emulated as metadata only est le comportement normal, le plus stable et le plus performant pour votre machine.
Ce que cela implique pour vous :
• Ce qui fonctionne parfaitement : Toutes les APIs AWS, Azure ou GCP de Floci
(S3, DynamoDB, SQS, SNS, IAM, etc.) fonctionnent à 100 % de manière ultra-rapide. 
Vos données sont persistées dans votre dossier local ${MY_PWD}/sim-cloud-floci-podman/floci-data.

Ce qui tourne en simulation (Metadata) : Si vous créez une instance EC2, Floci simulera son cycle de vie (statut Pending, Running, Stopped). Vous pouvez tester vos scripts d'infrastructure (Terraform, Ansible), mais vous ne pourrez pas vous connecter en SSH à l'intérieur de la fausse instance puisqu'elle n'a pas de conteneur physique dédié


