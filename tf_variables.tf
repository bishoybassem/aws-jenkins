variable "region" {
  description = "Name of the AWS region to use"
  default     = "eu-central-1"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair"
  default     = "aws"
}

variable "jenkins_version" {
  description = "Jenkins version to use"
  default     = "2.222.1"
}

variable "swarm_plugin_version" {
  description = "Swarm plugin version to use"
  default     = "3.18"
}

variable "slave_count" {
  default     = 1
  description = "Minimum number of slaves to have"
}

variable "slave_max_count" {
  default     = 3
  description = "Maximum number of slaves possible"
}
