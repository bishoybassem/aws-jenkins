output "jenkins_master_public_dns" {
  value = aws_eip.jenkins_master_ip.public_dns
}

output "admin_pass" {
  value = random_password.admin_pass.result
}