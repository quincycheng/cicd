#!/bin/bash -e

####################
# Configuration
####################


export server_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'|grep -v 172*)
export gitlab_root_password=$(openssl rand -hex 12)
export jenkins_admin_password=$(openssl rand -hex 12)
export awx_password=$(openssl rand -hex 12)
export jenkins_admin_user=admin
export conjur_account=demo
export admin_email=admin@admin.local


rm -rf ./workspace
mkdir ./workspace

echo "#################################"
echo "# ansible"
echo "#################################"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


[[ -n `which ansible-playbook` ]] || $DIR/install_ansible.sh

ansible-galaxy install cyberark.conjur
ansible-galaxy install drhelius.docker


echo "Ansible is ready!."

echo "#################################"
echo "# Docker Platform"
echo "#################################"

ansible-playbook ./playbook/setup_docker.yml

echo "#################################"
echo "# Pull Images"
echo "#################################"

docker-compose pull
docker pull openjdk:8-jre-alpine

echo "#################################"
echo "# Generate Conjur Data Key"
echo "#################################"

docker-compose run --no-deps --rm conjur data-key generate > data_key
export CONJUR_DATA_KEY="$(< data_key)"


echo "#################################"
echo "# Deploy Containers"
echo "#################################"

SERVER_IP=${server_ip} \
GITLAB_ROOT_PASSWORD=${gitlab_root_password} \
GITLAB_ROOT_EMAIL=${admin_email} \
docker-compose up -d


echo "#################################"
echo "# Setup iptables"
echo "#################################"

ansible-playbook playbook/setup_iptables.yml


echo "#################################"
echo "# Setup Conjur Account"
echo "#################################"

conjur_admin_api=$(docker-compose exec conjur conjurctl account create ${conjur_account})
conjur_pass=$(echo ${conjur_admin_api}|sed 's/.* //')

echo "#################################"
echo "# Setup Jenkins"
echo "#################################"


if [ ! -d downloads ]; then
    mkdir downloads

    curl  -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o ./downloads/jdk-9.0.4_linux-x64_bin.tar.gz http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz
    curl  -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o ./downloads/jdk-8u162-linux-x64.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u162-b12/0da788060d494f5095bf8624735fa2f1/jdk-8u162-linux-x64.tar.gz

    curl -o ./downloads/apache-maven-3.5.3-bin.tar.gz http://apache.communilink.net/maven/maven-3/3.5.3/binaries/apache-maven-3.5.3-bin.tar.gz

    curl -L -o downloads/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 chmod +x downloads/jq

fi

docker cp ./downloads/jdk-9.0.4_linux-x64_bin.tar.gz  cicd_jenkins:/tmp/jdk-9.0.4_linux-x64_bin.tar.gz
docker cp ./downloads/jdk-8u162-linux-x64.tar.gz cicd_jenkins:/tmp/jdk-8u162-linux-x64.tar.gz
docker cp ./downloads/apache-maven-3.5.3-bin.tar.gz cicd_jenkins:/tmp/apache-maven-3.5.3-bin.tar.gz

docker cp ./jenkins/plugins.txt cicd_jenkins:/tmp/plugins.txt
docker exec cicd_jenkins sh -c 'xargs /usr/local/bin/install-plugins.sh < /tmp/plugins.txt' || true

theScript=`cat ./jenkins/java.groovy`
curl -d "script=${theScript}" http://${server_ip}:32080/scriptText

theScript=`cat ./jenkins/maven.groovy`
curl -d "script=${theScript}" http://${server_ip}:32080/scriptText

theScript=`cat ./jenkins/security.groovy`
curl -d "script=${theScript//xPASSx/$jenkins_admin_password}" http://${server_ip}:32080/scriptText

docker restart cicd_jenkins

echo "#################################"
echo "# Download Summon"
echo "#################################"

curl -L -o downloads/summon.tar.gz https://github.com/cyberark/summon/releases/download/v0.6.6/summon-linux-amd64.tar.gz
curl -L -o downloads/summon-conjur.tar.gz https://github.com/cyberark/summon-conjur/releases/download/v0.5.0/summon-conjur-linux-amd64.tar.gz

cd downloads/
tar zvxf summon.tar.gz
tar zvxf summon-conjur.tar.gz
cd ..

echo "#################################"
echo "# Setup AWX"
echo "#################################"

cd downloads

pip uninstall -y docker
pip install docker==2.6.1

if [ ! -d awx ]; then
  git clone https://github.com/ansible/awx.git
fi

cd ./awx/installer
sed -i "s,host_port=80,host_port=34080,g" ./inventory
sed -i "s,.*default_admin_password=.*,default_admin_password=${awx_password},g" ./inventory
sed -i "s,# default_admin_user=admin,default_admin_user=admin,g" ./inventory
ansible-playbook -i inventory install.yml
cd ../../..


docker network connect cicd_default rabbitmq
docker network connect cicd_default postgres
docker network connect cicd_default memcached
docker network connect cicd_default awx_web
docker network connect cicd_default awx_task

echo "#################################"
echo "# Create Docker Service Account"
echo "#################################"
ansible-playbook playbook/create_docker_user.yml
DOCKER_SSH_KEY="/home/cicd_service_account/.ssh/id_rsa"

echo "#################################"
echo "# Setup Gitlab & CI runner"
echo "#################################"

docker exec cicd_gitlab gem install mechanize
docker cp ./gitlab/getcitoken.rb cicd_gitlab:/tmp/getcitoken.rb
docker exec cicd_gitlab chmod +x /tmp/getcitoken.rb


# Wait for GITLAB web service
while [[ "$(curl --write-out %{http_code} --silent --output /dev/null http://gitlab.${server_ip}.xip.io:31080/users/sign_in)" != "200" ]]; do 
    printf '.'
    sleep 5
done

# Wait for GITLAB Runner Registration Token
until [[ -z "$(docker exec cicd_gitlab ruby /tmp/getcitoken.rb | grep 'Error')"   ]]; do sleep 5s ; done
CI_SERVER_TOKEN="$(docker exec cicd_gitlab ruby /tmp/getcitoken.rb)"

docker exec cicd_gitlab_runner gitlab-runner register --non-interactive \
  --url "http://gitlab.${server_ip}.xip.io:31080/" \
  -r "${CI_SERVER_TOKEN}" \
  --executor shell


docker exec cicd_gitlab_runner gitlab-runner start


echo "#################################"
echo "# Save details to result file"
echo "#################################"

cat > ./workspace/config << EOL
SERVER_IP=${server_ip} 
CONJUR_DATA_KEY=${CONJUR_DATA_KEY}
CONJUR_URL=conjur.${server_ip}.xip.io:8080
CONJUR_USER=admin
CONJUR_PASS=${conjur_pass}
CONJUR_ACCOUNT=${conjur_account}
GITLAB_URL=gitlab.${server_ip}.xip.io:31080
GITLAB_USER=root
GITLAB_PASS=${gitlab_root_password} 
GITLAB_EMAIL=${admin_email} 
GITLAB_CI_SERVER_TOKEN=${CI_SERVER_TOKEN}
JENKINS_URL=jenkins.${server_ip}.xip.io:32080
JENKINS_USER=admin
JENKINS_PASS=${jenkins_admin_password}
ARTIFACTORY_URL=artifactory.${server_ip}.xip.io:33081
ARTIFACTORY_USER=admin
ARTIFACTORY_PASS=password
SONAR_URL=sonar.${server_ip}.xip.io:34000
SONAR_USER=admin
SONAR_PASS=admin
SCOPE_URL=scope.${server_ip}.xip.io:4040
AWX_URL=awx.${server_ip}.xip.io:34080
AWX_USER=admin
AWX_PASS=${awx_password}
DOCKER_SSH_USER=cicd_service_account
DOCKER_SSH_KEY="${DOCKER_SSH_KEY}"

EOL

cat > ./workspace/conjur_config << EOL
CONJUR_API="${conjur_admin_api}"
EOL

rm -f data_key

bin/print_login.sh
