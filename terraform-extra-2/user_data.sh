#!/bin/bash

sudo apt install -y golang nginx postgresql-client-common
sudo groupadd golang
sudo useradd -m -g golang golang

git clone https://github.com/Tabatskyi/golang-demo
sudo chown -R golang:golang /home/golang/golang-demo

cd /home/golang/golang-demo

GOOS=linux GOARCH=amd64 go build -o golang-demo
chmod +x golang-demo

psql -h ${DB_ENDPOINT} -U posthres -d postgres -a -f db_schema.sql
DB_ENDPOINT=${DB_ENDPOINT} DB_PORT=5432 DB_USER=postgres DB_PASS=ohiorizz DB_NAME=postgres ./golang-demo

sudo tee /etc/systemd/system/golang-demo.service > /dev/null <<EOL
      [Unit]
      Description=Golang Demo Service
      After=network.target

      [Service]
      User=golang
      Group=golang
      Environment="DB_ENDPOINT=${DB_ENDPOINT}"
      Environment="DB_PORT=5432"
      Environment="DB_USER=postgres"
      Environment="DB_PASS=rizzohio"
      Environment="DB_NAME=PostgresDB"
      ExecStart=/home/golang/golang-demo
      Restart=on-failure
      RestartSec=5
      StartLimitInterval=0
      [Install]
      WantedBy=multi-user.target
      EOL

sudo systemctl enable golang-demo
sudo systemctl start golang-demo

sudo tee /etc/nginx/sites-available/golang-demo > /dev/null <<EOL
      server {
          listen 80;
          server_name localhost;

          location / {
              proxy_pass http://127.0.0.1:8080;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto \$scheme;
          }
      }
      EOL

sudo ln -s /etc/nginx/sites-available/golang-demo /etc/nginx/sites-enabled/
sudo systemctl restart nginx
sudo systemctl enable nginx
