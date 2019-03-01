
# AWS Jenkins

This project sets up a secure scalable Jenkins cluster on AWS using Terraform. 

## Features
The setup features the following:
* A VPC with an IPv4 block (10.0.0.0/16).
* A public subnet for the internet facing machines (Jenkins master) and a private one (for the slave machines).
* Connections (e.g. SSH) to the slave machines can be only initiated from the master machine, i.e. the master acts as a bastion host.
* The private subnet can connect to the internet through a NAT server, which is the master machine in this setup 
(due to free tier limitations, but ideally it would be a different machine).
* The bootstrapping of the master and the slaves is performed at the startup of the machines with cloud-init.
* A reverse-proxy (Nginx) runs on master and enforces HTTPS communication (self-signed ssl certificate). 
* Terraform generates a secure random password for the admin account, and only passes it's hash to the master's init scripts. This way, the password is kept safe and does not leave the place where Terraform store's its state.
* Using the [Swarm plugin](https://wiki.jenkins.io/display/JENKINS/Swarm+Plugin), the slaves are able to join the master and manage their own configuration, thus simplifying scaling up/down the slaves. 

## Steps
1. Install Terraform (used version 0.11.11) and check that  `~/.aws/credentials` is present and contains the access keys of your IAM user ([guide here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)). 

2. Run Terraform as follows:
   ```bash
   terraform apply -var key_pair_name=aws -var slave_count=3
   ```
   Where `key_pair_name` is the name of a key pair that you created earlier ([guide here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)), and `slave_count` is the desired number of slaves to launch.
   
3. Check the output, which would look like the following:
   ```
   Outputs:
   
   admin_pass = ****************
   jenkins_master_public_dns = ec2-35-157-225-150.eu-central-1.compute.amazonaws.com
   jenkins_slave_private_ips = [
       10.0.1.189,
       10.0.1.201
   ]
   ```
4. Open the shown public dns in your browser, and login as `admin` with the output password.

5. To SSH into one of the slaves, SSH first into the master machine and then into the slave, or shortly as:
   ```bash
   ssh -J admin@ec2-35-157-225-150.eu-central-1.compute.amazonaws.com admin@10.0.1.189
   ```

6. Finally, to delete and free up all used resources:
   ```bash
   terraform destroy
   ```
   
## Running locally with Docker
For testing/demo purposes, you can run the same setup locally with Docker (used version 18.09.0-ce) and Docker Compose (used version 1.23.1) as follows:
```bash
   cd ./playground
   docker-compose up --scale slave=3
```
After that, open `https://localhost` in your browser, and login as `admin` with password `admin123`.