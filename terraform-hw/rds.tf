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
