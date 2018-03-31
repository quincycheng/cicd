#!/bin/bash
source ./workspace/config


# Copy Files
docker exec awx_task mkdir -p /var/lib/awx/projects/InsecureDemo
docker exec awx_web mkdir -p /var/lib/awx/projects/InsecureDemo

docker cp awx/InsecureDemo/ awx_task:/var/lib/awx/projects/
docker cp awx/InsecureDemo/ awx_web:/var/lib/awx/projects/

# Create Project
AWX_PROJECT_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/projects/ \
   -d '{ "name": "Insecure Demo", "description": "Insecure Demo", "local_path": "InsecureDemo"}'| jq -r '.id')

echo "project id: ${AWX_PROJECT_ID}"

# Create Org
AWX_ORG_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/organizations/ \
   -d '{ "name": "Insecure Demo", "description": "Insecure Demo"}' | jq -r '.id')

echo "org id: ${AWX_ORG_ID}"

# Create Inventory

AWX_INVENTORY_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/inventories/ \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"organization\": ${AWX_ORG_ID} }" | jq -r '.id')

echo "inventory id: ${AWX_INVENTORY_ID}"


# Create Host
AWX_HOST_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/hosts/ \
   -d "{ \"name\": \"${SERVER_IP}\", \"description\": \"Docker Insecure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"enabled\": true }" | jq -r '.id')


echo "host id: ${AWX_HOST_ID}"

# Create Job Template
AWX_TEMPLATE_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/job_templates/ \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"inventory\": $AWX_INVENTORY_ID, \
         \"project\": $AWX_PROJECT_ID, \"playbook\": \"deploy.yml\", \"extra_vars\": \"\" }" | jq -r '.id')

echo "template id: ${AWX_TEMPLATE_ID}"


# Copy Keys

docker cp ~cicd_service_account/.ssh/id_rsa awx_task:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa awx_web:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_task:/tmp/id_rsa.pub
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_web:/tmp/id_rsa.pub

