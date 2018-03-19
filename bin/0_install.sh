#!/bin/bash -e

####################
# Configuration
####################


export server_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'|grep -v 172*)
export gitlab_root_password=$(openssl rand -hex 12)
export jenkins_admin_password=$(openssl rand -hex 12)
export jenkins_admin_user=admin
export conjur_account=demo
export admin_email=admin@admin.local
export result_txt_file=demo_login

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


echo "#################################"
echo "# Setup Jenkins"
echo "#################################"


if [ ! -d downloads ]; then
    mkdir downloads

    curl  -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o ./downloads/jdk-9.0.4_linux-x64_bin.tar.gz http://download.oracle.com/otn-pub/java/jdk/9.0.4+11/c2514751926b4512b076cc82f959763f/jdk-9.0.4_linux-x64_bin.tar.gz
    curl  -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o ./downloads/jdk-8u162-linux-x64.tar.gz http://download.oracle.com/otn-pub/java/jdk/8u162-b12/0da788060d494f5095bf8624735fa2f1/jdk-8u162-linux-x64.tar.gz

    curl -o ./downloads/apache-maven-3.5.3-bin.tar.gz http://apache.communilink.net/maven/maven-3/3.5.3/binaries/apache-maven-3.5.3-bin.tar.gz
fi

docker cp ./downloads/jdk-9.0.4_linux-x64_bin.tar.gz  cicd_jenkins:/tmp/jdk-9.0.4_linux-x64_bin.tar.gz
docker cp ./downloads/jdk-8u162-linux-x64.tar.gz cicd_jenkins:/tmp/jdk-8u162-linux-x64.tar.gz
docker cp ./downloads/apache-maven-3.5.3-bin.tar.gz cicd_jenkins:/tmp/apache-maven-3.5.3-bin.tar.gz

docker cp ./jenkins/plugins.txt cicd_jenkins:/tmp/plugins.txt
docker exec cicd_jenkins sh -c 'xargs /usr/local/bin/install-plugins.sh < /tmp/plugins.txt'


theScript=`cat ./jenkins/java.groovy`
curl -d "script=${theScript}" http://${server_ip}:32080/scriptText

theScript=`cat ./jenkins/maven.groovy`
curl -d "script=${theScript}" http://${server_ip}:32080/scriptText

theScript=`cat ./jenkins/security.groovy`
curl -d "script=${theScript//xPASSx/$jenkins_admin_password}" http://${server_ip}:32080/scriptText


docker restart cicd_jenkins

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


rm -f  ${result_txt_file}.txt
touch ${result_txt_file}.txt
cat > ${result_txt_file}.txt << EOL

CICD Demo Login Details

[Conjur]
url:      http://conjur.${server_ip}.xip.io:8080"
url:      https://conjur.${server_ip}.xip.io:8433"
${conjur_admin_api}

[Gitlab]
url:  http://gitlab.${server_ip}.xip.io:31080
user: root
pass: ${gitlab_root_password}

[Jenkins]
url:  http://jenkins.${server_ip}.xip.io:32080
user: admin
pass: ${jenkins_admin_password}

[JFrog Artifactory]
url:  http://artifactory.${server_ip}.xip.io:33081
user: admin
pass: password

[SonarQube]
url:  http://sonar.${server_ip}.xip.io:34000
user: admin
pass: admin

[WeaveScope]
url:  http://scope.${server_ip}.xip.io:4040
EOL

cat ${result_txt_file}.txt
echo "The above details can be found in ${result_txt_file}.txt"
