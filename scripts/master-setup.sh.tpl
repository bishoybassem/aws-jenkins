#!/bin/bash -e

# Configure Jenkins to skip the initial setup wizard.
sed -i 's/^JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /' /etc/default/jenkins

# Download plugins.
mkdir /var/lib/jenkins/plugins
cd /var/lib/jenkins/plugins
wget https://updates.jenkins.io/${jenkins_version}/latest/matrix-auth.hpi
wget https://updates.jenkins.io/download/plugins/swarm/${swarm_plugin_version}/swarm.hpi
chown -R jenkins:jenkins /var/lib/jenkins

# Disable Nginx default welcome page.
cd /etc/nginx
rm sites-enabled/default

# Generate a self-signed certificate for ssl communication.
public_host_name=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
openssl req -newkey rsa:2028 -nodes -keyout server.pem -x509 -subj "/CN=$public_host_name" -days 1000 -out server.crt