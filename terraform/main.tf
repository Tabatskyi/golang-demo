terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.70.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
  shared_credentials_files = ["$HOME/.aws/credentials"]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_security_group" "ec2_security_group" {
  name        = "ec2-security-group"
  description = "Allow SSH and HTTP inbound traffic, and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name = "EC2 Group"
  }
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index)
  availability_zone = element(["eu-north-1a", "eu-north-1b", "eu-north-1c"], count.index % 3)

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_instance" "app_server" {
  ami               = "ami-08eb150f611ca277f"
  instance_type     = "t3.micro"
  availability_zone = "eu-north-1a"
  security_groups   = ["GolangNginxGroup"]
  
  user_data = <<-EOF
              #!/bin/bash

              sudo apt-get update
              sudo apt-get install -y golang nginx

              sudo groupadd golang
              sudo useradd -m -g golang golang
	      
	      git clone https://github.com/Tabatskyi/golang-demo
	      sudo chown -R golang:golang /home/golang/golang-demo

              cd /home/golang/golang-demo

              sudo tee /etc/systemd/system/golang-demo.service > /dev/null <<EOL
              [Unit]
              Description=Golang Demo Service
              After=network.target

              [Service]
              User=golang
              Group=golang
              Environment="DB_ENDPOINT=${aws_db_instance.postgresql.endpoint}"
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
              EOF

  tags = {
    Name = "GolangDemo"
  }
}

resource "aws_db_instance" "postgresql" {
  identifier        = "golang-demo-db"
  allocated_storage = 20
  instance_class    = "db.t4g.micro"
  engine            = "postgres"
  engine_version    = "16.3"
  username          = "postgres"
  password          = "rizzohio"  
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  parameter_group_name = "task-17-09"
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  skip_final_snapshot = true

  tags = {
    Name = "PostgresDB"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "db-subnet-group"
  }
}

resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Allow PostgreSQL access from EC2 instances"
  vpc_id      = aws_vpc.main.id  # Make sure this is the correct VPC ID

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}

