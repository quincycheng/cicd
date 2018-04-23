#!/bin/bash
curl -X POST --user JENKINS_USER:${INSECURE_JENKINS_PASS} --header "JOB-TOKEN: $CI_JOB_TOKEN" "JENKINS_URL/job/InsecureDemo/build"
