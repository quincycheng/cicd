#!/bin/bash
source ./workspace/config

install_summon() {

docker cp ./downloads/summon $2:/usr/local/bin
docker exec -u 0 $2 mkdir -p /usr/local/lib/summon
docker cp ./downloads/summon-conjur $2:/usr/local/lib/summon

#docker exec -u 0 $2 sh -c "curl -sSL https://raw.githubusercontent.com/cyberark/summon/master/install.sh | bash"
#docker exec -u 0 $2 sh -c "curl -sSL https://raw.githubusercontent.com/cyberark/summon-conjur/master/install.sh | bash"

#docker cp ./policy/installSummon.sh  $2:/tmp/installSummon.sh
#docker exec -u 0 $2 sh -c "/tmp/installSummon.sh"

#  docker exec -u 0 $2 sh -c "echo 'CONJURRC=/etc/conjur.conf' >> /etc/environment"
#  docker exec -u 0 $2 sh -c "echo 'export CONJURRC=/etc/conjur.conf' >> /etc/profile.d/conjur.sh"
#  docker exec -u 0 $2 sh -c "chmod +x /etc/profile.d/conjur.sh"

docker cp ./policy/enroll.sh  $2:/tmp/enroll.sh
docker cp ./downloads/jq $2:/usr/local/bin

  echo "[$2]"
  int_ip="$(docker inspect $2 | jq -r '.[0].NetworkSettings.Networks.cicd_default.IPAddress')"
  echo "ip: $int_ip"
  hf_token="$(docker exec cicd_client conjur hostfactory tokens create --duration-minutes 1 --cidr $int_ip/32 $3 | jq -r '.[0].token')"
  echo "hf: $hf_token"
  docker exec -u 0 $2 sh -c "/tmp/enroll.sh $1 $2 $hf_token"
}


echo "#################################"
echo "# Load Conjur Policies"
echo "#################################"


chmod +x downloads/jq 

docker exec cicd_client sh -c "mkdir -p /tmp/policy"
docker cp ./policy cicd_client:/tmp
docker cp ./workspace/config cicd_client:/tmp/policy/

docker cp ${DOCKER_SSH_KEY} cicd_client:/tmp/policy/ida_rsa

docker exec cicd_client sh -c "/tmp/policy/loadpolicy.sh"


echo "#################################"
echo "# Summon & Enroll to Conjur"
echo "#################################"

install_summon ${CONJUR_ACCOUNT} cicd_gitlab_runner gitlab
install_summon ${CONJUR_ACCOUNT} cicd_jenkins jenkins
install_summon ${CONJUR_ACCOUNT} awx_task awx



echo "#################################"
echo "# Create AWX Secure Demo"
echo "#################################"

# Copy Keys
docker cp ~cicd_service_account/.ssh/id_rsa awx_task:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa awx_web:/tmp/id_rsa
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_task:/tmp/id_rsa.pub
docker cp ~cicd_service_account/.ssh/id_rsa.pub awx_web:/tmp/id_rsa.pub

# Copy Files
docker exec awx_task mkdir -p /var/lib/awx/projects/SecureDemo
docker exec awx_web mkdir -p /var/lib/awx/projects/SecureDemo

docker cp awx/SecureDemo/ awx_task:/var/lib/awx/projects/
docker cp awx/SecureDemo/ awx_web:/var/lib/awx/projects/

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
   -d '{ "name": "Secure Demo", "description": "Secure Demo"}' | jq -r '.id')

echo "AWX Organization ID: ${AWX_ORG_ID}"

# Create Project
AWX_PROJECT_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/projects/ \
   -d "{ \"name\": \"Secure Demo\", \"description\": \"Secure Demo\", \"local_path\": \"SecureDemo\", \
   \"organization\": ${AWX_ORG_ID} }"| jq -r '.id')

echo "AWX Project ID: ${AWX_PROJECT_ID}"

# Create Inventory
AWX_INVENTORY_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/inventories/ \
   -d "{ \"name\": \"Secure Demo\", \"description\": \"Secure Demo\", \"organization\": ${AWX_ORG_ID} }" | jq -r '.id')
echo "AWX Inventory ID: ${AWX_INVENTORY_ID}"

# Create Host
AWX_HOST_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/hosts/ \
   -d "{ \"name\": \"${SERVER_IP}\", \"description\": \"Docker Secure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"enabled\": true }" | jq -r '.id')
echo "AWX Host ID: ${AWX_HOST_ID}"

# Create Job Template
AWX_TEMPLATE_ID=$(curl -s -k -H "Content-Type: application/json" -X POST -u $AWX_USER:$AWX_PASS $AWX_URL/api/v2/job_templates/  \
   -d "{ \"name\": \"Secure Demo\", \"description\": \"Secure Demo\", \"inventory\": ${AWX_INVENTORY_ID}, \
         \"project\": ${AWX_PROJECT_ID}, \"playbook\": \"deploy.yml\", \"ask_variables_on_launch\": true }" | jq -r '.id')

echo "AWX Template ID: ${AWX_TEMPLATE_ID} "




echo "#################################"
echo "# Create Gitlab Secure Demo"
echo "#################################"

cp -r ./gitlab/Demo ./workspace/Demo
cp ./gitlab/SecureDemo/.gitlab-ci.yml ./workspace/Demo
cp ./gitlab/SecureDemo/callJenkins.sh ./workspace/Demo
cp ./gitlab/SecureDemo/secrets.yml ./workspace/Demo

sed -i "s,JENKINS_USER,${JENKINS_USER},g" ./workspace/Demo/callJenkins.sh
sed -i "s,JENKINS_URL,${JENKINS_URL},g" ./workspace/Demo/callJenkins.sh

cd workspace/Demo

rm -rf .git
git init
git add .
git commit -m "initial commit"
git push --set-upstream http://${GITLAB_USER}:${GITLAB_PASS}@${GITLAB_URL}/root/SecureDemo.git master

cd ..
cd ..

rm -rf workspace/Demo

echo "#################################"
echo "# Create Jenkins Secure Demo"
echo "#################################"

cp -r ./jenkins/SecureDemo/job.xml ./workspace/SecureJob.xml

sed -i "s,GITLAB_USER,${GITLAB_USER},g" ./workspace/SecureJob.xml
sed -i "s,GITLAB_URL,${GITLAB_URL},g" ./workspace/SecureJob.xml

sed -i "s,ARTIFACTORY_USER,${ARTIFACTORY_USER},g" ./workspace/SecureJob.xml
sed -i "s,ARTIFACTORY_URL,${ARTIFACTORY_URL},g" ./workspace/SecureJob.xml


AWX_CONTAINER_IP=$(docker inspect awx_web | jq -r '.[].NetworkSettings.Networks.cicd_default.IPAddress')


sed -i "s,AWX_CONTAINER_IP,${AWX_CONTAINER_IP},g" ./workspace/SecureJob.xml
sed -i "s,AWX_USER,${AWX_USER},g" ./workspace/SecureJob.xml
sed -i "s,AWX_TEMPLATE_ID,${AWX_TEMPLATE_ID},g" ./workspace/SecureJob.xml

docker cp ./workspace/SecureJob.xml cicd_jenkins:/tmp/SecureJob.xml
docker exec --user root cicd_jenkins sh -c "cd /tmp && curl -L -s -k  http://${JENKINS_URL}/jnlpJars/jenkins-cli.jar -o/tmp/jenkins-cli.jar"
docker exec --user root cicd_jenkins sh -c "java -jar /tmp/jenkins-cli.jar -auth ${JENKINS_USER}:${JENKINS_PASS} -s http://${JENKINS_URL} create-job SecureDemo < /tmp/SecureJob.xml"

rm -f  ./workspace/SecureJob.xml

echo "#################################"
echo "# Secure Demo Deployed"
echo "#################################"
