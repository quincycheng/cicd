source ./workspace/config


echo "#################################"
echo "# Create Gitlab Insecure Demo"
echo "#################################"

cp -r ./gitlab/Demo ./workspace/Demo
cp ./gitlab/InsecureDemo/.gitlab-ci.yml ./workspace/Demo

sed -i "s,JENKINS_USER,${JENKINS_USER},g" ./workspace/Demo/.gitlab-ci.yml
sed -i "s,JENKINS_PASS,${JENKINS_PASS},g" ./workspace/Demo/.gitlab-ci.yml
sed -i "s,JENKINS_URL,${JENKINS_URL},g" ./workspace/Demo/.gitlab-ci.yml

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

docker cp ./workspace/InsecureJob.xml cicd_jenkins:/tmp/InsecureJob.xml
docker exec cicd_jenkins sh -c "cd /tmp && wget http://${JENKINS_URL}/jnlpJars/jenkins-cli.jar /tmp/jenkins-cli.jar"
docker exec cicd_jenkins sh -c "java -jar /tmp/jenkins-cli.jar -auth ${JENKINS_USER}:${JENKINS_PASS} -s http://${JENKINS_URL} create-job InsecureDemo < /tmp/InsecureJob.xml"

rm -f  ./workspace/InsecureJob.xml
