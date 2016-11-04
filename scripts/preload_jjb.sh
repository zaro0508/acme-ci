#!/usr/bin/env bash

set -e

git clone https://git.openstack.org/openstack-infra/jenkins-job-builder /home/vagrant/jenkins-job-builder
sudo chgrp -R vagrant /home/vagrant/jenkins-job-builder
sudo chown -R vagrant /home/vagrant/jenkins-job-builder
