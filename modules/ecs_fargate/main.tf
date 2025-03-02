# Define AWS Region
provider "aws" {
  region = var.region
}

#Define VPC
resource "aws_vpc" "main" {
  cidr_block = "10.70.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

#Define Subnet
resource "aws_subnet" "fargate_subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.70.10.0/27"
    availability_zone = "${var.region}a"
    map_public_ip_on_launch = true
}

#Internet Gateway
resource "aws_internet_gateway" "fargate_igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fargate_igw"
  }
}

#Route Table
resource "aws_route_table" "fargate_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fargate_igw.id
  }

  tags = {
    Name = "fargate_rt"
  }
}

#Associate Route Table with Subnet
resource "aws_route_table_association" "fargate_association" {
     subnet_id = aws_subnet.fargate_subnet.id
     route_table_id = aws_route_table.fargate_rt.id
}

#Security Group
resource "aws_security_group" "fargate_sg" {
    name_prefix = "Allow-3000-80"
    vpc_id = aws_vpc.main.id

    dynamic "ingress" {
        for_each = var.allowed_ports
        content {
             from_port   = ingress.value
             to_port     = ingress.value
            protocol    = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
    }
  }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
        
    }
}

#IAM Role
resource "aws_iam_role" "ecs_fargate_task_execution_role" {
  name = "ecs_fargate_task_execution_role"

  assume_role_policy = jsonencode({ 
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role = aws_iam_role.ecs_fargate_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
#ECS Cluster
resource "aws_ecs_cluster" "fargate_cluster" {
  name = "fargate_cluster"
}

#Grafana Task Definition
resource "aws_ecs_task_definition" "grafana_task" {
  family = "grafana-task"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_fargate_task_execution_role.arn

  container_definitions = jsonencode([
    {
        name = "grafana"
        image = "grafana/grafana:latest"
         portMappings = [
        {
          containerPort = 3000
        }
      ]
    }
  ])
}

#NGINX Task Definition

resource "aws_ecs_task_definition" "nginx_task" {
  family = "nginx-task"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_fargate_task_execution_role.arn

  container_definitions = jsonencode([
    {
        name = "nginx"
        image = "nginx:latest"
        portMappings =[
            {
                containerPort = 80           
           }
        ]
    }
  ])
}

#Grafana Service
resource "aws_ecs_service" "grafana_service" {
  name = "grafana-service"
  cluster = aws_ecs_cluster.fargate_cluster.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.fargate_subnet.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }
  desired_count = 1
}

resource "aws_ecs_service" "nginx_service" {
  name = "nginx-service"
  cluster = aws_ecs_cluster.fargate_cluster.id
  task_definition = aws_ecs_task_definition.nginx_task.arn
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.fargate_subnet.id]
    security_groups = [aws_security_group.fargate_sg.id]
    assign_public_ip = true
  }

  desired_count = 1
}