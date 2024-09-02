resource "aws_vpc" "one" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"
  enable_dns_hostnames = var.host_name

  tags = {
    Name = "TOT-vpc"
  }
}
resource "aws_subnet" "sub1" {
  vpc_id     = aws_vpc.one.id
  cidr_block = "10.0.1.0/24"
  availability_zone       = "us-east-1e"

  tags = {
    Name = "sub-one"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id     = aws_vpc.one.id
  cidr_block = "10.0.2.0/24"
  availability_zone       = "us-east-1f"

  tags = {
    Name = "sub-two"
  }
}

# IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.one.id

  tags = {
    Name = "Gateway"
  }
}

# Route table
resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.one.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route-table-one"
  }
}
# Association 
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.route1.id
}

resource "aws_route_table" "route2" {
  vpc_id = aws_vpc.one.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "route-table-two"
  }
}
# Association 
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.route2.id
}

# security group
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow web and ssh traffic"
  vpc_id      = aws_vpc.one.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_instance" "master" {
  ami                           = var.ami_id
  instance_type                 = var.inst_type
  subnet_id                     = aws_subnet.sub1.id
  key_name                      = var.key
  associate_public_ip_address   = var.public_key
  security_groups               = [aws_security_group.public_sg.id]
  user_data                   = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install httpd -y
                              systemctl start httpd
                              systemctl enable httpd
                              EOF
  tags = {
    name = "Master"
}

}

resource "aws_instance" "slave" {
  ami                           = var.ami_id
  instance_type                 = var.inst_type
  subnet_id                     = aws_subnet.sub2.id
  key_name                      = var.key
  associate_public_ip_address   = var.public_key
  security_groups               = [aws_security_group.public_sg.id]
  user_data                   = <<-EOF
                              #!/bin/bash
                              apt update -y
                              apt install httpd -y
                              systemctl start httpd
                              systemctl enable httpd
                              EOF
  tags = {
    name = "slaves1"
}
}

# Application load balancer
resource "aws_lb" "mani" {
  name               = "Application"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets         = [aws_subnet.sub1.id,aws_subnet.sub2.id]
  
  tags = {
    Environment = "Rams"
  }
}
# target group
resource "aws_lb_target_group" "test" {
  name     = "padayappa"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.one.id

  depends_on = [aws_vpc.one]
}

resource "aws_lb_target_group_attachment" "testrt" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.master.id
  port             = 80

  depends_on = [aws_instance.master]
}
resource "aws_lb_target_group_attachment" "testrt2" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.slave.id
  port             = 80

  depends_on = [aws_instance.slave]
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.mani.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}


