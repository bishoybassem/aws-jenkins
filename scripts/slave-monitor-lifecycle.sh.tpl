#!/bin/bash -e

# Check whether the instance is terminating.
instance_id=$(curl -sf -m 1 http://169.254.169.254/latest/meta-data/instance-id)
status=$(aws autoscaling describe-auto-scaling-instances --instance-ids $${instance_id} --query 'AutoScalingInstances[*].LifecycleState' --output text)
if [ "$status" != "Terminating:Wait" ]; then
    exit 0
fi

# Fetch the jenkins-cli in case it wasn't already.
if [ ! -f /opt/jenkins-cli.jar ]; then
    wget -O /opt/jenkins-cli.jar  ${master_url}/jnlpJars/jenkins-cli.jar
fi

# Mark the slave as offline, so that it won't accept more builds.
java -jar /opt/jenkins-cli.jar -s ${master_url} offline-node $${instance_id} -m "The machine is terminating"

# If the slave is idle/not running any builds, then complete the lifecycle hook, otherwise, record a heartbeat to extend the wait timeout.
is_idle=$(curl -sf -m 1 ${master_url}/computer/$${instance_id}/api/json | python -c 'import json, sys; print(json.load(sys.stdin)["idle"])')
if [ "$is_idle" = "True" ]; then
    aws autoscaling complete-lifecycle-action --instance-id $${instance_id} --lifecycle-action-result CONTINUE --lifecycle-hook-name slave_termination_hook --auto-scaling-group-name jenkins_slaves
else
    aws autoscaling record-lifecycle-action-heartbeat --instance-id $${instance_id} --lifecycle-hook-name slave_termination_hook --auto-scaling-group-name jenkins_slaves
fi