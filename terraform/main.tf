terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.70.0"
    }
  }
}

provider "aws" {
  region                 = "eu-north-1"
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

resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Allow PostgreSQL access from EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
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

resource "aws_lb" "main" {
  name               = "golang-demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_security_group.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "main-alb"
  }
}

resource "aws_lb_target_group" "main" {
  name     = "golang-demo-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  tags = {
    Name = "main-target-group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_launch_template" "main" {
  name          = "golang-demo-launch-template"
  instance_type = "t3.micro"
  image_id      = "ami-08eb150f611ca277f"

  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  user_data = base64encode(<<-EOF
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
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "golang-demo-instance"
    }
  }
}

resource "aws_autoscaling_group" "main" {
  desired_capacity = 2
  max_size         = 3
  min_size         = 1
  vpc_zone_identifier = aws_subnet.public[*].id
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main.arn]

  tag {
      key                 = "Name"
      value               = "golang-demo-autoscaling"
      propagate_at_launch = true
    }
  
}

resource "aws_db_instance" "postgresql" {
  identifier            = "golang-demo-db"
  allocated_storage     = 20
  instance_class        = "db.t4g.micro"
  engine                = "postgres"
  engine_version        = "16.3"
  username              = "postgres"
  password              = "rizzohio"
  db_subnet_group_name  = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  skip_final_snapshot   = true

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

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  count      = length(aws_subnet.public[*].id)
  subnet_id  = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

