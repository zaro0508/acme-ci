#!/bin/bash
virtualenv seedenv
source $WORKSPACE/seedenv/bin/activate
sudo pip install jenkins-job-builder==1.6.1
jenkins-jobs --conf $WORKSPACE/data/jenkins-job-builder/jenkins.ini update --delete-old $WORKSPACE/data/jenkins-job-builder/demo/jobs

