[Unit]
Description=Jenkins slave service

[Service]
ExecStart=/bin/bash -c "java \
            -Djava.util.logging.config.file=/opt/swarm-client-logging.properties \
            -jar /opt/swarm-client.jar \
            -master ${master_url} \
            -name $(curl -sf -m 1 http://169.254.169.254/latest/meta-data/instance-id) \
            -disableClientsUniqueId \
            -deleteExistingClients"
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target