#!/bin/bash -e

echo "Configuring AWS CLI to fetch credentials from the instance's metadata..."
mkdir ~/.aws
tee ~/.aws/config <<EOF
[default]
region = $(ec2metadata --availability-zone | sed 's/.$//')
credential_source = Ec2InstanceMetadata
EOF

function get_tag_value() {
	instance_id=$(ec2metadata --instance-id)
	aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=tag:$1,Values=*" \
		--query 'Tags[*].Value' --output text
}

cd /opt

echo "Downloading swarm client..."
swarm_plugin_version=$(get_tag_value SwarmPluginVersion)
wget -O swarm-client.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${swarm_plugin_version}/swarm-client-${swarm_plugin_version}.jar

echo "Trusting the master's certificate..."
master_host=$(get_tag_value MasterHost)
openssl s_client -connect $master_host:443 -showcerts </dev/null 2>/dev/null | openssl x509 \
	> /usr/local/share/ca-certificates/jenkins-master.crt
update-ca-certificates

echo "Enabling systemd service..."
systemctl enable jenkins-slave

echo "Installing and configuring CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 \
	-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "Configuring a cron job to monitor lifecycle hooks..."
echo '* * * * * /usr/local/bin/monitor-lifecycle' | crontab -