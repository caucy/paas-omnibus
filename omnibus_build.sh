#!/bin/bash -e

###########################
#
# WARNING: You need to rebuild the docker images if you do any changes to this file
#
############################

PROJECT_DIR=paas-agent-omnibus
PROJECT_NAME=paas-agent
LOG_LEVEL=${LOG_LEVEL:-"info"}

cd PROJECT_DIR
set -e

# Clean up omnibus artifacts
rm -rf /var/cache/omnibus/pkg/*

# Clean up what we installed
rm -f /etc/init.d/paas-agent
rm -rf /etc/paas-agent
rm -rf /opt/$PROJECT_NAME/*

# Install the gems we need, with stubs in bin/
bundle update # Make sure to update to the latest version of omnibus-software
bin/omnibus build -l=$LOG_LEVEL $PROJECT_NAME
