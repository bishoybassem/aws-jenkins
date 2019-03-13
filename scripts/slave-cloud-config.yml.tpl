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
- path: /usr/local/bin/monitor-lifecycle
  permissions: '0755'
  encoding: b64
  content: ${base64encode(monitor_lifecycle_script)}

hostname: ci-slave

apt_update: true
apt_upgrade: true

packages:
- openjdk-8-jre

runcmd:
- wget -O /opt/swarm-client.jar https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/${swarm_plugin_version}/swarm-client-${swarm_plugin_version}.jar
- systemctl enable jenkins-slave
- echo '* * * * * /usr/local/bin/monitor-lifecycle' | crontab -

power_state:
  delay: now
  mode: reboot