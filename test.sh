#!/bin/bash
source ./workspace/config
AWX_INVENTORY_ID=3
AWX_PROJECT_ID=8


# Create Job Template
AWX_TEMPLATE_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/job_templates/  \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"project\": ${AWX_PROJECT_ID}, \"playbook\": \"deploy.yml\", \"ask_variables_on_launch\": true }" )

echo "AWX Template ID: ${AWX_TEMPLATE_ID} "
