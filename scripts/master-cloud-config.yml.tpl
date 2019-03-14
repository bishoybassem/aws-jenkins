#cloud-config

bootcmd:
# Enable packet forwarding and nat slave traffic.
- sysctl -w net.ipv4.ip_forward=1
- iptables -t nat -A POSTROUTING -s ${slaves_subnet} -o eth0 -j MASQUERADE

# Prevent auto service startup while installing packages.
- echo 'exit 101' > /usr/sbin/policy-rc.d
- chmod +x /usr/sbin/policy-rc.d

# Add the key for Jenkins debian repository.
- wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -

write_files:
- path: /var/lib/jenkins/.admin_pass_hash
  permissions: '0400'
  content: "${admin_pass_hash}"
- path: /var/lib/jenkins/.slave_pass
  permissions: '0400'
  content: "${slave_pass}"
- path: /var/lib/jenkins/.monitoring_pass
  permissions: '0400'
  content: "${monitoring_pass}"
- path: /etc/nginx/conf.d/jenkins.conf
  permissions: '0640'
  encoding: b64
  content: ${base64encode(nginx_conf)}
- path: /var/lib/jenkins/init.groovy
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/master-configure-security.groovy"))}
- path: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/master-cloudwatch-agent-config.json"))}
- path: /usr/local/bin/push-monitoring-metrics
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("scripts/master-push-monitoring-metrics.sh"))}

hostname: ci-master

apt:
  sources:
    jenkins.list:
      source: "deb http://pkg.jenkins.io/debian-stable binary/"
      # Key added above from the official url.

apt_update: true
apt_upgrade: true

packages:
- openjdk-8-jre
- [jenkins, ${jenkins_version}.*]
- nginx

power_state:
  delay: now
  mode: reboot