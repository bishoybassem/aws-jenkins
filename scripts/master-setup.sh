#!/bin/bash -e

region=$(ec2metadata --availability-zone | sed 's/.$//')

# Configure AWS CLI to fetch credentials from the instance's metadata.
mkdir ~/.aws
tee ~/.aws/config <<EOF
[default]
region = ${region}
credential_source = Ec2InstanceMetadata
EOF

# Query Jenkins and Swarm plugin versions from the instance's tags.
instance_id=$(ec2metadata --instance-id)
jenkins_version=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" \
	'Name=tag:JenkinsVersion,Values=*' --query 'Tags[*].Value' --output text)
jenkins_version_major_minor=$(echo ${jenkins_version} | sed -r 's/([^\.]+\.[^\.]+).*/\1/')
swarm_plugin_version=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" \
	'Name=tag:SwarmPluginVersion,Values=*' --query 'Tags[*].Value' --output text)

# Install Jenkins from the official debian repository
apt-get install -y --no-install-recommends gnupg2
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
echo "deb http://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends jenkins=$jenkins_version

# Configure AWS CLI for Jenkins user
cp -r ~/.aws /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins/.aws

# Configure Jenkins to skip the initial setup wizard.
sed -i 's/^JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /' /etc/default/jenkins

# Generate random password for monitoring user. SecretsManager was not used here, as this user
# is only used on the master machine. 
openssl rand -hex 16 > /var/lib/jenkins/.monitoring_pass

# Download plugins.
mkdir /var/lib/jenkins/plugins
cd /var/lib/jenkins/plugins
wget https://updates.jenkins.io/${jenkins_version_major_minor}/latest/matrix-auth.hpi
wget https://updates.jenkins.io/${jenkins_version_major_minor}/latest/authorize-project.hpi
wget https://updates.jenkins.io/download/plugins/swarm/${swarm_plugin_version}/swarm.hpi
chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Disable Nginx default welcome page.
cd /etc/nginx
rm sites-enabled/default

# Generate a self-signed certificate for ssl communication.
public_ip=$(aws ec2 describe-addresses --filter 'Name=tag:Name,Values=jenkins_master' \
	--query 'Addresses[*].PublicIp' --output text)
public_hostname="ec2-$(echo ${public_ip} | sed 's/\./-/g').$region.compute.amazonaws.com"
private_ip=$(hostname -I)
openssl req -newkey rsa:2048 -nodes -keyout server.pem \
	-x509 -subj "/CN=$public_hostname" -addext "subjectAltName = IP:$public_ip, IP:$private_ip" \
	-days 1000 -out server.crt
cp server.crt /usr/local/share/ca-certificates/jenkins-master.crt
update-ca-certificates

# Install and configure CloudWatch agent.
cd /opt
wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 \
	-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Configure a cron job to push metrics to CloudWatch agent using StatsD protocol.
echo '* * * * * /usr/local/bin/push-monitoring-metrics' | crontab -u jenkins -