#!/bin/bash -e

function get_tag_value() {
	instance_id=$(ec2metadata --instance-id)
	aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=tag:$1,Values=*" \
		--query 'Tags[*].Value' --output text
}

export SLAVE_USER_PASSWORD="$(aws secretsmanager get-secret-value --secret-id jenkins-slave-password \
	--query SecretString --output text)"

exec java -Djava.util.logging.config.file=/opt/swarm-client-logging.properties \
	-jar /opt/swarm-client.jar \
	-master https://$(get_tag_value MasterHost) \
	-username slave \
	-passwordEnvVariable SLAVE_USER_PASSWORD \
	-name $(ec2metadata --instance-id) \
	-disableClientsUniqueId \
	-deleteExistingClients \
	-executors $(get_tag_value NumExecutors)