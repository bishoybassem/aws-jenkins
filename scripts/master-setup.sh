#!/bin/bash -e

region=$(ec2metadata --availability-zone | sed 's/.$//')

# Configure AWS CLI to fetch credentials from the instance's metadata.
mkdir ~/.aws
tee ~/.aws/config <<EOF
[default]
region = ${region}
credential_source = Ec2InstanceMetadata
EOF

public_ip=$(aws ec2 describe-addresses --filter 'Name=tag:Name,Values=jenkins_master' --query 'Addresses[*].PublicIp' --output text)
public_hostname="ec2-$(echo ${public_ip} | sed 's/\./-/g').$region.compute.amazonaws.com"
instance_id=$(ec2metadata --instance-id)

# Query Jenkins and Swarm plugin versions from the instance's tags.
jenkins_version=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" 'Name=tag:JenkinsVersion,Values=*' --query 'Tags[*].Value' --output text)
jenkins_version_major_minor=$(echo ${jenkins_version} | sed -r 's/([^\.]+\.[^\.]+).*/\1/')
swarm_plugin_version=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" 'Name=tag:SwarmPluginVersion,Values=*' --query 'Tags[*].Value' --output text)

# Configure Jenkins to skip the initial setup wizard.
sed -i 's/^JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /' /etc/default/jenkins

# Download plugins.
mkdir /var/lib/jenkins/plugins
cd /var/lib/jenkins/plugins
wget https://updates.jenkins.io/${jenkins_version_major_minor}/latest/matrix-auth.hpi
wget https://updates.jenkins.io/${jenkins_version_major_minor}/latest/authorize-project.hpi
wget https://updates.jenkins.io/download/plugins/swarm/${swarm_plugin_version}/swarm.hpi
chown -R jenkins:jenkins /var/lib/jenkins

# Disable Nginx default welcome page.
cd /etc/nginx
rm sites-enabled/default

# Generate a self-signed certificate for ssl communication.
openssl req -newkey rsa:2028 -nodes -keyout server.pem -x509 -subj "/CN=$public_hostname" -days 1000 -out server.crt

# Install and configure CloudWatch agent.
cd /opt
wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Configure a cron job to push metrics to CloudWatch agent using StatsD protocol.
echo '* * * * * /usr/local/bin/push-monitoring-metrics' | crontab -u jenkins -