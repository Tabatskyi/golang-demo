resource "aws_launch_template" "main" {
  name          = "golang-demo-launch-template"
  instance_type = "t3.micro"
  image_id      = "ami-08eb150f611ca277f"

  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  user_data = base64encode(templatefile("user_data.sh", {
    DB_ENDPOINT = aws_db_instance.postgresql.endpoint
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "golang-demo-instance"
    }
  }
}

resource "aws_autoscaling_group" "main" {
  desired_capacity = 1
  max_size         = 2
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
