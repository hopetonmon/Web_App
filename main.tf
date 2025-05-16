terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
        }
    }
    
    required_version = ">= 1.0.0"
}

#-------------------TERRAFORM CLOUD---------------------
# This block configures the Terraform Cloud backend for storing the state file remotely.
terraform { 
  cloud { 
    
    organization = "Foundationmon" 

    workspaces { 
      name = "Web_App" 
    } 
  } 
}

#-----------------------VARIABLES-----------------------------
variable "HOPETONMON_COPY_ACCESS_KEY" {
    description = "HopetonMon Copy AWS Access Key"
    type        = string
    sensitive = true
}

variable "HOPETONMON_COPY_SECRET_KEY" {
    description = "HopetonMon Copy AWS Secret Key"
    type        = string
    sensitive = true
  
}

variable "AWS_REGION" {
    description = "AWS Region"
    type        = string
}

variable "AVAILABILITY_ZONE" {
    description = "Availability Zone (Distinct loaction in the Region)"
    type        = string
}

variable "AVAILABILITY_ZONE2" {
    description = "Availability Zone 2 (Distinct loaction in the Region)"
    type        = string
  
}

#------------------PROVIDERS----------------------
provider "aws" {
    region     = var.AWS_REGION
    access_key = var.HOPETONMON_COPY_ACCESS_KEY
    secret_key = var.HOPETONMON_COPY_SECRET_KEY
  
}

#-------------------VPC---------------------
resource "aws_vpc" "web_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true #Enables or disables DNS resolution within the VPC.
    enable_dns_hostnames = false # Enables or disables the assignment of public DNS hostnames to instances launched in the VPC.
    tags = {
        Name = "web_vpc"
    }
}

#-------------------SUBNETS---------------------
resource "aws_subnet" "web_subnet1" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone =  var.AVAILABILITY_ZONE
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "web_subnet"
    }
}

resource "aws_subnet" "web_subnet2" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = var.AVAILABILITY_ZONE2
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "web_subnet2"
    }
  
}

#-------------------INTERNET GATEWAY---------------------
resource "aws_internet_gateway" "web_igw" {
    vpc_id = aws_vpc.web_vpc.id
    tags = {
        Name = "web_igw"
    }
}

#-------------------ROUTE TABLE---------------------
resource "aws_route_table" "web_route_table" {
    vpc_id = aws_vpc.web_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.web_igw.id
  
}
    tags = {
        Name = "web_route_table"
    }
}

#-------------------ROUTE TABLE ASSOCIATION---------------------
resource "aws_route_table_association" "web_route_table_assoc" {
    subnet_id      = aws_subnet.web_subnet.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.web_route_table.id
}

resource "aws_route_table_association" "web_route_table_assoc2" {
    subnet_id      = aws_subnet.web_subnet2.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.web_route_table.id
}

#-------------------LOAD BALANCER---------------------
resource "aws_lb" "web_alb" {
    name               = "web-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets            = [aws_subnet.web_subnet1, aws_subnet.web_subnet2.id]  
    enable_http2 = true

    tags = {
        Name = "web_alb"
    }
}
#-------------------TARGET GROUP---------------------
resource "aws_lb_target_group" "web_target_group" { #Target Group is used by the ALB to route requests to the registered EC2 instances.
    name     = "web-target-group"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.web_vpc.id

    health_check {
        path                = "/"
        interval            = 30
        timeout             = 5
        healthy_threshold  = 2
        unhealthy_threshold = 2
    }

    tags = {
        Name = "web_target_group"
    }
}
#-------------------SECURITY GROUP---------------------
resource "aws_security_group" "web_sg" {
    vpc_id = aws_vpc.web_vpc.id
    name   = "web_sg"
    description = "Allow HTTP and SSH traffic"
  
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # Allow HTTP traffic from anywhere
    } 
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # Allow SSH traffic from any(where
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1" # Allow all outbound traffic with any protocol
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "web_sg"
    }
}

resource "aws_security_group" "alb_sg" { #Security Group for ALB
  vpc_id = aws_vpc.web_vpc.id
  name   = "alb_sg"
  ingress {
    description = "HTTP from anywhere"
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
    Name = "alb_sg"
  }
}

#-------------------EC2 INSTANCE---------------------
resource "aws_instance" "web_instance" {
    ami           = "ami-0dba2cb6798deb6d8" # Ubuntu 20.04 LTS
    instance_type = "t2.micro"
    subnet_id     = aws_subnet.web_subnet.id
    vpc_security_group_ids = [aws_security_group.web_sg.id]
    key_name      = "car_key" #The key pair is used for authentication when connecting to the instance via SSH.
  
    # User data script to install and start Nginx, This script will run when the instance is launched
    # 1.)This starts a shell script using Bash running on the instances first boot.
    # 2.)Updates the package list
    # 3.)Installs Nginx
    # 4.)Starts the Nginx service
    # 5.)Enables Nginx to start on boot
    # 6.)Ends the script

      user_data = <<-EOF
        #!/bin/bash
        sudo apt update
        sudo apt install -y nginx
        echo "<h1>Hello from My Terraform Web Server!</h1><p>This message was deployed using Terraform user_data.</p>" | sudo tee /var/www/html/index.html
        sudo systemctl start nginx
        sudo systemctl enable nginx
    EOF
 
    tags = {
        Name = "web_instance"
    }
}

#-------------------OUTPUTS---------------------
output "web_instance_public_ip" {  #After running terraform apply, Terraform will display the output values directly in the console. Additionally, you can view all outputs later by running: terraform apply
  value = aws_instance.web_instance.public_ip
}
