#!/bin/bash

monitoring_pass=$(cat /var/lib/jenkins/.monitoring_pass)
if curl -sf -m 1 -u monitoring:${monitoring_pass} http://localhost:8080 &> /dev/null; then
    guage=1
else
    guage=0
fi
echo "jenkins.service:$guage|g" | nc -w 1 -u localhost 8125

queue_length=$(curl -sf -m 1 -u monitoring:${monitoring_pass} http://localhost:8080/queue/api/json | python -c 'import json, sys; print(len(json.load(sys.stdin)["discoverableItems"]))')
if [ $? -eq 0 ]; then
    echo "jenkins.queue:$queue_length|g" | nc -w 1 -u localhost 8125
fi