[Unit]
Description=Jenkins slave service

[Service]
ExecStart=/usr/bin/java -jar /opt/swarm-client.jar -master ${master_url}
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target