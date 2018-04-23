#!/bin/bash
source ./workspace/config

echo "#################################"
echo "# Create AWX Insecure Demo"
echo "#################################"

# Copy Keys
docker cp ~cicd_service_account/.ssh/id_rsa awx_task:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa awx_web:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_task:/tmp/id_rsa.pub
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_web:/tmp/id_rsa.pub

# Copy Files
docker exec awx_task mkdir -p /var/lib/awx/projects/InsecureDemo
docker exec awx_web mkdir -p /var/lib/awx/projects/InsecureDemo

docker cp awx/InsecureDemo/ awx_task:/var/lib/awx/projects/
docker cp awx/InsecureDemo/ awx_web:/var/lib/awx/projects/

# Wait for AWX Web ready
printf 'Waiting for AWX REST API...'
until [[ "$(curl -u ${AWX_USER}:${AWX_PASS} -s -k -L http://${AWX_URL}/api/v2/me|grep count)" ]];
do
    printf '.'
    sleep 5s
done
echo ""

# Create Org
AWX_ORG_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/organizations/ \
   -d '{ "name": "Insecure Demo", "description": "Insecure Demo"}' | jq -r '.id')

echo "AWX Organization ID: ${AWX_ORG_ID}"

# Create Project
AWX_PROJECT_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/projects/ \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"local_path\": \"InsecureDemo\", \
   \"organization\": ${AWX_ORG_ID} }"| jq -r '.id')

echo "AWX Project ID: ${AWX_PROJECT_ID}"

# Create Inventory
AWX_INVENTORY_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/inventories/ \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"organization\": ${AWX_ORG_ID} }" | jq -r '.id')
echo "AWX Inventory ID: ${AWX_INVENTORY_ID}"

# Create Host
AWX_HOST_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/hosts/ \
   -d "{ \"name\": \"${SERVER_IP}\", \"description\": \"Docker Insecure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"enabled\": true }" | jq -r '.id')
echo "AWX Host ID: ${AWX_HOST_ID}"

# Create Job Template
AWX_TEMPLATE_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/job_templates/  \
   -d "{ \"name\": \"Insecure Demo\", \"description\": \"Insecure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"project\": ${AWX_PROJECT_ID}, \"playbook\": \"deploy.yml\", \"ask_variables_on_launch\": true }" | jq -r '.id')

echo "AWX Template ID: ${AWX_TEMPLATE_ID} "




echo "#################################"
echo "# Create Gitlab Insecure Demo"
echo "#################################"

cp -r ./gitlab/Demo ./workspace/Demo
cp ./gitlab/InsecureDemo/.gitlab-ci.yml ./workspace/Demo
cp ./gitlab/InsecureDemo/callJenkins.sh ./workspace/Demo
cp ./gitlab/InsecureDemo/pom.xml ./workspace/Demo

sed -i "s,JENKINS_URL,${JENKINS_URL},g" ./workspace/Demo/callJenkins.sh
sed -i "s,JENKINS_USER,${JENKINS_USER},g" ./workspace/Demo/callJenkins.sh
sed -i "s,INSECURE_JENKINS_PASS: JENKINS_PASS,INSECURE_JENKINS_PASS: ${JENKINS_PASS},g" ./workspace/Demo/.gitlab-ci.yml

cd workspace/Demo

rm -rf .git
git init
git add .
git commit -m "initial commit"
git push --set-upstream http://${GITLAB_USER}:${GITLAB_PASS}@${GITLAB_URL}/root/InsecureDemo.git master

cd ..
cd ..

rm -rf workspace/Demo

echo "#################################"
echo "# Create Jenkins Insecure Demo"
echo "#################################"

cp -r ./jenkins/InsecureDemo/job.xml ./workspace/InsecureJob.xml

sed -i "s,GITLAB_USER,${GITLAB_USER},g" ./workspace/InsecureJob.xml
sed -i "s,GITLAB_PASS,${GITLAB_PASS},g" ./workspace/InsecureJob.xml
sed -i "s,GITLAB_URL,${GITLAB_URL},g" ./workspace/InsecureJob.xml

sed -i "s,ARTIFACTORY_USER,${ARTIFACTORY_USER},g" ./workspace/InsecureJob.xml
sed -i "s,ARTIFACTORY_PASS,${ARTIFACTORY_PASS},g" ./workspace/InsecureJob.xml
sed -i "s,ARTIFACTORY_URL,${ARTIFACTORY_URL},g" ./workspace/InsecureJob.xml


AWX_CONTAINER_IP=$(docker inspect awx_web | jq -r '.[].NetworkSettings.Networks.cicd_default.IPAddress')


sed -i "s,AWX_CONTAINER_IP,${AWX_CONTAINER_IP},g" ./workspace/InsecureJob.xml
sed -i "s,AWX_USER,${AWX_USER},g" ./workspace/InsecureJob.xml
sed -i "s,AWX_PASS,${AWX_PASS},g" ./workspace/InsecureJob.xml
sed -i "s,AWX_TEMPLATE_ID,${AWX_TEMPLATE_ID},g" ./workspace/InsecureJob.xml

docker cp ./workspace/InsecureJob.xml cicd_jenkins:/tmp/InsecureJob.xml
docker exec --user root cicd_jenkins sh -c "cd /tmp && curl -L -s -k  http://${JENKINS_URL}/jnlpJars/jenkins-cli.jar -o/tmp/jenkins-cli.jar"
docker exec --user root cicd_jenkins sh -c "java -jar /tmp/jenkins-cli.jar -auth ${JENKINS_USER}:${JENKINS_PASS} -s http://${JENKINS_URL} create-job InsecureDemo < /tmp/InsecureJob.xml"

rm -f  ./workspace/InsecureJob.xml

echo "#################################"
echo "# Insecure Demo Deployed"
echo "#################################"
