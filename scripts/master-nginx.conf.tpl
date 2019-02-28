server {
    listen                80 default_server;
    server_name           _;
    return                301 https://$host$request_uri;
}

server {
    listen                443 ssl;

    ssl_certificate       server.crt;
    ssl_certificate_key   server.pem;
    ssl_session_cache     shared:SSL:10m;

    location / {
        proxy_pass        http://127.0.0.1:8080;
        proxy_set_header  Host $host:$server_port;
        proxy_set_header  X-Real-IP $remote_addr;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto $scheme;
    }
}

server {
    listen 8082;
    location / {
        proxy_pass        http://127.0.0.1:8080;
        proxy_set_header  Authorization "Basic ${auth_header}";
        proxy_set_header  Host $host:$server_port;
        proxy_set_header  X-Real-IP $remote_addr;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto $scheme;
    }
}