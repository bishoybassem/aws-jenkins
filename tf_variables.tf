variable "region" {
  description = "Name of the AWS region to use"
  default     = "eu-central-1"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair"
  default     = "aws"
}

variable "vpc_id" {
  description = "VPC id to use (if set, this module would skip creating one)"
  default     = ""
}

variable "ig_id" {
  description = "Internet gateway id to use in the VPC (if set, this module would skip creating one)"
  default     = ""
}

variable "cidr_vpc" {
  description = "IPv4 address block for the VPC (if one would be created)"
  default     = "10.0.0.0/16"
}

variable "cidr_public_subnet" {
  description = "IPv4 address block for the public subnet"
  default     = "10.0.1.0/24"
}

variable "cidr_private_subnet_1" {
  description = "IPv4 address block for the first private subnet"
  default     = "10.0.2.0/24"
}

variable "cidr_private_subnet_2" {
  description = "IPv4 address block for the second private subnet"
  default     = "10.0.3.0/24"
}

variable "jenkins_version" {
  description = "Jenkins version to use"
  default     = "2.222.1"
}

variable "swarm_plugin_version" {
  description = "Swarm plugin version to use"
  default     = "3.19"
}

variable "additional_plugins" {
  description = "List of additional plugins to install, format: 'plugin_id:version' (omitting the ':version' part would install the latest)"
  type    = list(string)
  default = ["git", "workflow-aggregator:2.6", "job-dsl:1.77"]
}

variable "instance_type_master" {
  description = "EC2 Instance type for the master"
  default     = "t2.micro"
}

variable "instance_type_slave" {
  description = "EC2 Instance type for a slave"
  default     = "t2.micro"
}

variable "num_executors_master" {
  description = "Number of executors on the master"
  default     = 1
}

variable "num_executors_slave" {
  description = "Number of executors on a slave"
  default     = 2
}

variable "slave_count" {
  default     = 1
  description = "Minimum number of slaves to have"
}

variable "slave_max_count" {
  default     = 3
  description = "Maximum number of slaves possible"
}

variable "master_recover_system_failure_period" {
  default     = 2
  description = "Time period (in minutes) after which the master instance is recovered in case the system status check is failing"
}

variable "master_restart_service_down_period" {
  default     = 2
  description = "Time period (in minutes) after which the master instance is restarted in case the Jenkins service is down"
}

variable "slaves_scale_out_queue_size" {
  default     = 2
  description = "Number of builds which, if the queue size exceeds/equals, triggers a scale out"
}

variable "slaves_scale_out_queue_size_period" {
  default     = 5
  description = "Time period (in minutes) over which the queue size constraint for scaling out is evaluated"
}

variable "slaves_scale_in_queue_size" {
  default     = 1
  description = "Number of builds which, if the queue size goes below, triggers a scale in"
}

variable "slaves_scale_in_queue_size_period" {
  default     = 10
  description = "Time period (in minutes) over which the queue size constraint for scaling in is evaluated"
}