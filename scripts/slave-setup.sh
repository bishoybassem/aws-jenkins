#!/bin/bash -e

# Configure AWS CLI to fetch credentials from the instance's metadata.
mkdir ~/.aws
tee ~/.aws/config <<EOF
[default]
region = $(ec2metadata --availability-zone | sed 's/.$//')
credential_source = Ec2InstanceMetadata
EOF

instance_id=$(ec2metadata --instance-id)

# Query Swarm plugin version from the instance's tags.
swarm_plugin_version=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" 'Name=tag:SwarmPluginVersion,Values=*' --query 'Tags[*].Value' --output text)

# Download swarm client.
wget -O /opt/swarm-client.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${swarm_plugin_version}/swarm-client-${swarm_plugin_version}.jar

# Enable systemd service.
systemctl enable jenkins-slave

# Install and configure CloudWatch agent.
cd /opt
wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Configure a cron job to monitor lifecycle hooks.
echo '* * * * * /usr/local/bin/monitor-lifecycle' | crontab -