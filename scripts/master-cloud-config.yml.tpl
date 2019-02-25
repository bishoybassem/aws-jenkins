#cloud-config

apt_update: true
apt_upgrade: true
apt_reboot_if_required: true

write_files:
- path: /var/lib/jenkins/.admin_pass_hash
  permissions: '0400'
  content: ${admin_pass_hash}
- path: /var/lib/jenkins/init.groovy
  permissions: '0644'
  encoding: b64
  content: ${base64encode(init_groovy)}