#!/bin/bash 
source /tmp/policy/config

conjur init -u conjur -a ${CONJUR_ACCOUNT} --force=~/.conjurrc

cat > ~/.netrc << EOF
machine http://conjur/authn
  login ${CONJUR_USER}
  password ${CONJUR_PASS}

EOF

chmod 0600 ~/.netrc

cat /tmp/policy/gitlab.yml  \
    /tmp/policy/jenkins.yml \
    /tmp/policy/sonar.yml \
    /tmp/policy/artifactory.yml \
    /tmp/policy/awx.yml \
    /tmp/policy/docker.yml \
  > /tmp/policy/conjur.yml

conjur policy load --replace root /tmp/policy/conjur.yml

conjur variable values add gitlab/password ${GITLAB_PASS}
conjur variable values add jenkins/password ${JENKINS_PASS}
conjur variable values add sonar/password ${SONAR_PASS}
conjur variable values add artifactory/password ${ARTIFACTORY_PASS}
conjur variable values add awx/password ${AWX_PASS}
conjur variable values add docker/ssh_private_key  /tmp/policy/ida_rsa

cat /tmp/policy/entitlement.yml >> /tmp/policy/conjur.yml
conjur policy load root /tmp/policy/conjur.yml

