#!/bin/bash

install_summon() {
  docker cp ./downloads/summon $1:/usr/local/bin
  docker exec $1 mkdir -p /usr/local/lib/summon
  docker cp ./downloads/summon $1:/usr/local/lib/summon
}

source ./workspace/config

echo "#################################"
echo "# Load Conjur Policies"
echo "#################################"

docker exec cicd_client sh -c "mkdir -p /tmp/policy"
docker cp ./policy cicd_client:/tmp
docker cp ./workspace/config cicd_client:/tmp/policy/

docker exec cicd_client sh -c "/tmp/policy/loadpolicy.sh"

exit 1

echo "#################################"
echo "# Install Summon to containers"
echo "#################################"

install_summon cicd_gitlab_runner
install_summon cicd_jenkins

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
