#!/bin/bash -e

instance_id=$(ec2metadata --instance-id)

# Check whether the instance is terminating.
status=$(aws autoscaling describe-auto-scaling-instances --instance-ids ${instance_id} --query 'AutoScalingInstances[*].LifecycleState' --output text)
if [ "$status" != "Terminating:Wait" ]; then
    exit 0
fi

# Query the master's private ip address.
master_url="https://$(aws ec2 describe-addresses --filter 'Name=tag:Name,Values=jenkins_master' --query 'Addresses[*].PrivateIpAddress' --output text)"

# Fetch the jenkins-cli in case it wasn't already.
if [ ! -f /opt/jenkins-cli.jar ]; then
    wget -O /opt/jenkins-cli.jar  ${master_url}/jnlpJars/jenkins-cli.jar
fi

# Set the slave user credentials in environment (used by jenkins-cli).
export JENKINS_USER_ID=slave
export JENKINS_API_TOKEN="$(aws secretsmanager get-secret-value --secret-id jenkins-slave-password --query SecretString --output text)"

# Mark the slave as offline, so that it won't accept more builds.
java -jar /opt/jenkins-cli.jar -s ${master_url} offline-node ${instance_id} -m "The machine is terminating"

# If the slave is idle/not running any builds, then complete the lifecycle hook, otherwise, record a heartbeat to extend the wait timeout.
is_idle=$(curl -sf -m 1 --config - ${master_url}/computer/${instance_id}/api/json <<< "user = slave:$JENKINS_API_TOKEN" | jq -r .idle)
if [ "$is_idle" = "true" ]; then
    aws autoscaling complete-lifecycle-action --instance-id ${instance_id} --lifecycle-action-result CONTINUE --lifecycle-hook-name slave_termination_hook --auto-scaling-group-name jenkins_slaves
else
    aws autoscaling record-lifecycle-action-heartbeat --instance-id ${instance_id} --lifecycle-hook-name slave_termination_hook --auto-scaling-group-name jenkins_slaves
fi