#!/bin/bash

# Conjur Tower CLI
export TOWER_HOST="http://awxweb:8052"
export TOWER_USERNAME=admin
export TOWER_VERIFY_SSL=False

# Get Credential ID
CID=$(tower-cli credential list --name docker_ssh_key -f id)

THEKEY=$(cat ${DOCKER_SSH_KEY})
echo "the key: $THEKEY"


THEVALUE="username: cicd_service_account
ssh_key_data: |
$(awk '{printf "      %s\n", $0}' < ${DOCKER_SSH_KEY})
"
echo "the value $THEVALUE"

# Update SSH Key
tower-cli credential modify --name docker_ssh_key --credential-type 1 --inputs "$THEVALUE" $CID

#{ username: \"cicd_service_account\", ssh_key_data: \"$(cat ${DOCKER_SSH_KEY})\n\"}" $CID 

#
# Note: There is no update credential function in Tower API (as of AWX 1.0.4)
#
#NEW_CONTENT=$(curl -s -k -H "Content-Type: application/json" -X GET -u admin:$AWX_PASS \
#   awxweb:8052/api/v2/credentials/ |
#   jq -r ".results[] | select(.name==\"docker_ssh_key\") + {inputs: { username: \"cicd_service_account\", ssh_key_data: \"${DOCKER_SSH_KEY}\" } }")
#
#curl -s -k -H "Content-Type: application/json" -X PUT -u admin:$AWX_PASS \
#   awxweb:8052/api/v2/credentials/ \
#   -d "$NEW_CONTENT"

