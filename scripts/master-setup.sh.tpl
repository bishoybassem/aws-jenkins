#!/bin/bash -e

# Prevent auto service startup while installing packages.
echo 'exit 101' > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

# Install Jenkins from the official repository.
echo 'deb http://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
apt-get update
apt-get install -y openjdk-8-jre jenkins=${jenkins_version}.*

# Configure Jenkins to skip the initial setup wizard
sed -i 's/^JAVA_ARGS=.*/JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"/' /etc/default/jenkins

# Download plugins
mkdir /var/lib/jenkins/plugins
cd /var/lib/jenkins/plugins
wget https://updates.jenkins.io/${jenkins_version}/latest/matrix-auth.hpi
chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
systemctl start jenkins