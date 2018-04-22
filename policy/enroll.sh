#!/bin/bash -e

function fetch_machine_identity() {

  ########### CHANGE VARIABLES BELOW ############
  local baseurl='http://conjur'
  local hostid="$2"
  local token="$3"
  local conjur_account="$1"
  ###############################################

  echo 'Fetching machine identity from Conjur using HF token'

  local status=$(curl -k -X POST -s -w '%{http_code}' \
    -o /tmp/host.json \
    -H "Authorization: Token token=\"$token\"" \
    $baseurl/host_factories/hosts?id=$hostid
  )


  if [ $status -eq 201 ]; then
    cat > /etc/conjur.identity <<EOF
machine $baseurl/authn
login host/$hostid
password $(jq -r '.api_key' /tmp/host.json)
EOF

    cat > /etc/conjur.conf << EOF
account: $conjur_account
plugins: []
appliance_url: http://conjur
netrc_path: /etc/conjur.identity
EOF

  else
    echo "Error! HTTP response: $status"
    exit 1
  fi
}

fetch_machine_identity $1 $2 $3
