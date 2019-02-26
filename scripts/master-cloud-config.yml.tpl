#cloud-config

bootcmd:
# Prevent auto service startup while installing packages.
- echo 'exit 101' > /usr/sbin/policy-rc.d
- chmod +x /usr/sbin/policy-rc.d

# Add the key for Jenkins debian repository.
- wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -

write_files:
- path: /var/lib/jenkins/.admin_pass_hash
  permissions: '0400'
  content: ${admin_pass_hash}
- path: /etc/nginx/conf.d/jenkins.conf
  permissions: '0640'
  encoding: b64
  content: ${base64encode(nginx_conf)}
- path: /var/lib/jenkins/init.groovy
  permissions: '0644'
  encoding: b64
  content: ${base64encode(init_groovy)}

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
  condition: ls /var/run/reboot-required