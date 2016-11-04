#!/usr/bin/env bash

set -e

sudo apt-get install -y git python-pip
sudo pip install tox
git clone https://git.openstack.org/openstack-infra/jenkins-job-builder /home/vagrant/jenkins-job-builder
sudo chgrp -R vagrant /home/vagrant/jenkins-job-builder
sudo chown -R vagrant /home/vagrant/jenkins-job-builder
