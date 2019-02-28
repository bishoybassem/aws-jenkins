[Unit]
Description=Jenkins slave service

[Service]
ExecStart=/usr/bin/java -Djava.util.logging.config.file=/opt/swarm-client-logging.properties -jar /opt/swarm-client.jar -master ${master_url} -name %H -deleteExistingClients
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target