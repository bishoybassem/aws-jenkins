#!/bin/bash -e

master_host="$(aws ec2 describe-addresses --filter 'Name=tag:Name,Values=jenkins_master' --query 'Addresses[*].PrivateIpAddress' --output text)"
export SLAVE_USER_PASSWORD="$(aws secretsmanager get-secret-value --secret-id jenkins-slave-password --query SecretString --output text)"

exec java -Djava.util.logging.config.file=/opt/swarm-client-logging.properties \
	-jar /opt/swarm-client.jar \
	-master https://$master_host \
	-username slave \
	-passwordEnvVariable SLAVE_USER_PASSWORD \
	-name $(ec2metadata --instance-id) \
	-disableClientsUniqueId \
	-deleteExistingClients