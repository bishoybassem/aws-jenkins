#cloud-config

write_files:
- path: /etc/systemd/system/jenkins-slave.service
  permissions: '0644'
  encoding: b64
  content: ${base64encode(slave_service)}
- path: /opt/swarm-client-logging.properties
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/slave-logging.properties"))}
- path: /root/.aws/config
  permissions: '0644'
  content: |
    [default]
    region = ${aws_region}
    credential_source = Ec2InstanceMetadata
- path: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/slave-cloudwatch-agent-config.json"))}
- path: /usr/local/bin/monitor-lifecycle
  permissions: '0755'
  encoding: b64
  content: ${base64encode(monitor_lifecycle_script)}

hostname: ci-slave

apt_update: true
apt_upgrade: true

packages:
- openjdk-8-jre

power_state:
  delay: now
  mode: reboot