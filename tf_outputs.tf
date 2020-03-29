output "jenkins_master_public_dns" {
  # Workaround the issue that terraform doesn't update the public dns name of the instance after elastic ip association.
  value = "ec2-${replace(aws_eip.jenkins_master_ip.public_ip, ".", "-")}.${var.region}.compute.amazonaws.com"
}

output "admin_pass" {
  value = random_password.admin_pass.result
}