provider "aws" {
  region = "ap-south-1"  # Change this to your desired AWS region
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  
  # Define your security group rules here, e.g., allow HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "harish-key"  # Replace with your desired key name
  public_key = file("/root/.ssh/harish.pub")  # Replace with the path to your harish.pem public key file
}

resource "aws_launch_configuration" "example" {
  name_prefix          = "example-"
  image_id             = "ami-067c21fb1979f0b27"  # Replace with your desired AMI
  instance_type        = "t2.micro"               # Replace with your desired instance type
  security_groups      = [aws_security_group.web.id]
  key_name             = aws_key_pair.my_key_pair.key_name  # Use the key pair name defined above
  user_data            = <<-EOF
                        #!/bin/bash
                        yum update -y
                        yum install -y httpd
                        systemctl start httpd
                        systemctl enable httpd
                        yum install -y docker
                        systemctl start docker
                        echo "this is a system configuration" >> clickops.conf
                        echo "<h1> welcome to clickops technologies , this website is running from \$(hostname -f) </h1>" > /var/www/html/clickops.html
                        EOF
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  name_prefix         = "example-"
  launch_configuration = aws_launch_configuration.example.name
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = ["subnet-021a5cf968ce090d8"]  # Replace with your desired subnet ID(s)
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  enable_deletion_protection = false
  
  enable_http2 = true

  subnets = ["subnet-021a5cf968ce090d8", "subnet-0a178d26da48c7543"]  # Replace with your desired subnet IDs
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      
    }
  }
}

resource "aws_lb_target_group" "example" {
  name     = "example-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-05e9eb62c8ee28ff8"  # Replace with your VPC ID

  health_check {
    path                = "/clickops.html"
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = aws_lb_listener.example.arn

  action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
     
    }
  }

  condition {
    path_pattern {
      values = ["/clickops.html"]
    }
  }
}

resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = aws_autoscaling_group.example.name
  lb_target_group_arn   = aws_lb_target_group.example.arn
}



output "load_balancer_dns_name" {
  value = aws_lb.example.dns_name
}

output "instance_user_data" {
  value = aws_launch_configuration.example.user_data
}