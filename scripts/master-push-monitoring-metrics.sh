#!/bin/bash

# Check whether Jenkins is responsive or not (through Nginx) and update the CloudWatch agent's metric.
monitoring_pass=$(cat /var/lib/jenkins/.monitoring_pass)
if curl -sfk -m 1 --config - https://localhost <<< "user = monitoring:$monitoring_pass" &> /dev/null; then
    guage=1
else
    guage=0
fi
echo "jenkins.service:$guage|g" | nc -w 1 -u localhost 8125

# Query the queue length and update the CloudWatch agent's metric.
queue_length=$(curl -sf -m 1 --config - http://localhost:8080/queue/api/json <<< "user = monitoring:$monitoring_pass" | jq '.discoverableItems | length')
if [ $? -eq 0 ]; then
    echo "jenkins.queue:$queue_length|g" | nc -w 1 -u localhost 8125
fi