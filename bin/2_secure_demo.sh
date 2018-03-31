#!/bin/bash
source ./workspace/config

install_summon() {
  docker cp ./downloads/summon $2:/usr/local/bin
  docker exec $2 mkdir -p /usr/local/lib/summon
  docker cp ./downloads/summon $2:/usr/local/lib/summon
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
echo "here1"
docker cp ./workspace/config cicd_client:/tmp/policy/
echo "here"

docker cp ${DOCKER_SSH_KEY} "/tmp/policy/ida_rsa"

docker exec cicd_client sh -c "/tmp/policy/loadpolicy.sh"


echo "#################################"
echo "# Summon & Enroll to Conjur"
echo "#################################"

install_summon ${CONJUR_ACCOUNT} cicd_gitlab_runner gitlab
install_summon ${CONJUR_ACCOUNT} cicd_jenkins jenkins
install_summon ${CONJUR_ACCOUNT} awx_task awx


exit 1

echo "#################################"
echo "# Create Gitlab Secure Demo"
echo "#################################"

cp -r ./gitlab/Demo ./workspace/Demo
cp ./gitlab/SecureDemo/.gitlab-ci.yml ./workspace/Demo

sed -i "s,JENKINS_USER,${JENKINS_USER},g" ./workspace/Demo/.gitlab-ci.yml
sed -i "s,JENKINS_PASS,${JENKINS_PASS},g" ./workspace/Demo/.gitlab-ci.yml
sed -i "s,JENKINS_URL,${JENKINS_URL},g" ./workspace/Demo/.gitlab-ci.yml

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
echo "# Create Jenkins Insecure Demo"
echo "#################################"

cp -r ./jenkins/InsecureDemo/job.xml ./workspace/SecureJob.xml

sed -i "s,GITLAB_URL,${GITLAB_URL},g" ./workspace/SecureJob.xml
sed -i "s,ARTIFACTORY_URL,${ARTIFACTORY_URL},g" ./workspace/SecureJob.xml

docker cp ./workspace/SecureJob.xml cicd_jenkins:/tmp/SecureJob.xml
docker exec cicd_jenkins sh -c "cd /tmp && wget http://${JENKINS_URL}/jnlpJars/jenkins-cli.jar /tmp/jenkins-cli.jar"
docker exec cicd_jenkins sh -c "summon java -jar /tmp/jenkins-cli.jar -auth ${JENKINS_USER}:${JENKINS_PASS} -s http://${JENKINS_URL} create-job SecureDemo < /tmp/SecureJob.xml"

rm -f  ./workspace/SecureJob.xml
