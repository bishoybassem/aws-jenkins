#cloud-config

bootcmd:
# Enable packet forwarding and nat slave traffic.
- sysctl -w net.ipv4.ip_forward=1
- iptables -t nat -A POSTROUTING -s ${slaves_subnet} -o eth0 -j MASQUERADE

# Prevent auto service startup while installing packages.
- echo 'exit 101' > /usr/sbin/policy-rc.d
- chmod +x /usr/sbin/policy-rc.d

write_files:
- path: /etc/nginx/conf.d/jenkins.conf
  permissions: '0640'
  encoding: b64
  content: ${base64encode(file("scripts/master-nginx.conf"))}
- path: /var/lib/jenkins/init.groovy
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/master-configure.groovy"))}
- path: /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
  permissions: '0644'
  encoding: b64
  content: ${base64encode(file("scripts/master-cloudwatch-agent-config.json"))}
- path: /usr/local/bin/push-monitoring-metrics
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("scripts/master-push-monitoring-metrics.sh"))}

hostname: ci-master

apt_update: true
apt_upgrade: true

packages:
- openjdk-11-jdk
- nginx
- unzip
- netcat
- jq

power_state:
  delay: now
  mode: reboot