#!/bin/bash

if curl -sf -m 1 http://localhost:8082 &> /dev/null; then
    guage=1
else
    guage=0
fi
echo "jenkins.service:$guage|g" | nc -w 1 -u localhost 8125