#!/bin/bash -e

region=$(ec2metadata --availability-zone | sed 's/.$//')

echo "Configuring AWS CLI to fetch credentials from the instance's metadata..."
mkdir ~/.aws
tee ~/.aws/config <<EOF
[default]
region = ${region}
credential_source = Ec2InstanceMetadata
EOF

function get_tag_value() {
	instance_id=$(ec2metadata --instance-id)
	aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=tag:$1,Values=*" \
		--query 'Tags[*].Value' --output text
}

echo "Installing Jenkins from the official debian repository..."
jenkins_version=$(get_tag_value JenkinsVersion)
apt-get install -y --no-install-recommends gnupg2
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
echo "deb http://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y --no-install-recommends jenkins=$jenkins_version

echo "Configuring AWS CLI for Jenkins user..."
cp -r ~/.aws /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins/.aws

echo "Configuring Jenkins to skip the initial setup wizard..."
sed -i 's/^JAVA_ARGS="/JAVA_ARGS="-Djenkins.install.runSetupWizard=false /' /etc/default/jenkins

echo "Generating random password for monitoring user..." 
# SecretsManager was not used here, as this user is only used on the master machine. 
openssl rand -hex 16 > /var/lib/jenkins/.monitoring_pass

echo "Disabling Nginx default welcome page..."
cd /etc/nginx
rm sites-enabled/default

echo "Generating a self-signed certificate for ssl communication..."
public_dns=$(get_tag_value PublicDNS)
public_ip=$(get_tag_value PublicIP)
openssl req -newkey rsa:2048 -nodes -keyout server.pem \
	-x509 -subj "/CN=$public_dns" -addext "subjectAltName = DNS:$public_dns, IP:$public_ip" \
	-days 1000 -out server.crt
cp server.crt /usr/local/share/ca-certificates/jenkins-master.crt
update-ca-certificates

echo "Installing and configuring CloudWatch agent..."
cd /opt
wget https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 \
	-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "Configuring a cron job to push metrics to CloudWatch agent using StatsD protocol..."
echo '* * * * * /usr/local/bin/push-monitoring-metrics' | crontab -u jenkins -

echo "Downloading plugins..."
mkdir /var/lib/jenkins/plugins
cd /var/lib/jenkins/plugins
wget https://raw.githubusercontent.com/jenkinsci/docker/master/install-plugins.sh
wget https://raw.githubusercontent.com/jenkinsci/docker/master/jenkins-support
chmod +x install-plugins.sh jenkins-support
mv jenkins-support /usr/local/bin
export REF=/var/lib/jenkins
export JENKINS_UC=https://updates.jenkins.io
swarm_plugin_version=$(get_tag_value SwarmPluginVersion)
additional_plugins="$(get_tag_value AdditionalPlugins | jq -r .[])"
for plugin in matrix-auth authorize-project script-security swarm:$swarm_plugin_version $additional_plugins; do
	./install-plugins.sh $plugin
done
chown -R jenkins:jenkins /var/lib/jenkins/plugins