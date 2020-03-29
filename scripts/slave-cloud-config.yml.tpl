#cloud-config

write_files:
- path: /etc/systemd/system/jenkins-slave.service
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/slave-jenkins.service"))}
- path: /usr/local/bin/start-slave
  permissions: '0754'
  encoding: b64
  content: ${base64encode(file("scripts/slave-start.sh"))}
- path: /opt/swarm-client-logging.properties
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/slave-logging.properties"))}
- path: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/slave-cloudwatch-agent-config.json"))}
- path: /usr/local/bin/monitor-lifecycle
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("scripts/slave-monitor-lifecycle.sh"))}

hostname: ci-slave

apt_update: true
apt_upgrade: true

packages:
- openjdk-11-jdk
- jq

power_state:
  delay: now
  mode: reboot