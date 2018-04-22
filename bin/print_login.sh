source ./workspace/config

cat << EOF
CICD Demo Login Details

[General]
Server IP:  ${SERVER_IP}

[Scope]
URL:  http://${SCOPE_URL}

[Gitlab]
URL:  http://${GITLAB_URL}
User: ${GITLAB_USER}
Pass: ${GITLAB_PASS}

[Jenkins]
URL:  http://${JENKINS_URL}
User: ${JENKINS_USER}
Pass: ${JENKINS_PASS}

[SonarQube]
URL:  http://${SONAR_URL}
User: ${SONAR_USER}
Pass: ${SONAR_PASS}

[Artifactory]
URL:  http://${ARTIFACTORY_URL}
User: ${ARTIFACTORY_USER}
Pass: ${ARTIFACTORY_PASS}

[AWX]
URL:  http://${AWX_URL}
User: ${AWX_USER}
Pass: ${AWX_PASS}

[Conjur]
URL:  http://${CONJUR_URL}
User: ${CONJUR_USER}
Pass: ${CONJUR_PASS}

[Demo]
Insecure:  http://${SERVER_IP}:8091/info
	   http://${SERVER_IP}:9091/health
Secure:    http://${SERVER_IP}:8099


EOF
