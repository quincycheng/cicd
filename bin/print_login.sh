source ./workspace/config

cat << EOF
CICD Demo Login Details

[General]
Server IP:  ${SERVER_IP}

[Conjur]
URL:  http://${CONJUR_URL}
User: ${CONJUR_USER}
Pass: ${CONJUR_PASS}

[Gitlab]
URL:  http://${GITLAB_URL}
User: ${GITLAB_USER}
Pass: ${GITLAB_PASS}

[Jenkins]
URL:  http://${JENKINS_URL}
User: ${JENKINS_USER}
Pass: ${JENKINS_PASS}

[Artifactory]
URL:  http://${ARTIFACTORY_URL}
User: ${ARTIFACTORY_USER}
Pass: ${ARTIFACTORY_PASS}

[SonarQube]
URL:  http://${SONAR_URL}
User: ${SONAR_USER}
Pass: ${SONAR_PASS}

[Scope]
URL:  http://${SCOPE_URL}
EOF
