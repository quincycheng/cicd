# CICD Demo

## Purpose
This repo serves for preparing a CI/CD pipeline environment for testing

## Install

type `bin\start.sh`

This script will install docker, docker-compose & ansible on the host, and configure the firewall using ansible iptables module.
Then create GitLab, GitLab runner, WeaveScope, Jenkins BlueOcean, Ansible, SonarQube, Artifactory & Conjur as containers
It also install 2 demos projects: Insecure demo & Secure Demo

### Host names
xip.io will be used for DNS names for containers.


### Login Details
By default, a text file will be generated, containing all the login url, username & passwords.

### Demo flow

Simply update the source in Gitlab, and the pipeline will be automatically triggered.
You can review .gitlab-ci.yml in GitLab, Jenkins project configuration and AWX playbook.
The insecure demo will have secrets hard-coded, while the secure demo will be secured by CyberArk Conjur


## Individual Componments

### Gitlab

Two containers are used, one for SCM & one for CI runner
A ruby script is used to get the registration token as there is no offical way to fetch it using CLI or API (as of 2018.03)

### Jenkins

- Single container is used to save the host resources
- Setup wizard is skipped
- security will be set automatically
- an admin account with random password will be created 

### Sonarqube

- Code Quality Check


### Artifactory

- Repo for Artifacts

### AWX / Ansible

- CD automation



## Useful Scripts

### bin/cleanup.sh
This script kills & removes all related containers


