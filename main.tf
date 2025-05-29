#-------------PROVIDER CONFIGURATION---------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.0"
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

variable "NEW_RELIC_ACCOUNT_ID" {
  description = "New Relic Account ID"
  type        = string
}

variable "NEW_RELIC_API_KEY" {
  description = "New Relic API Key"
  type        = string
  sensitive   = true
}

variable "NEW_RELIC_LICENSE_KEY" {
  description = "New Relic License Key"
  type        = string
  sensitive   = true
}
#------------------PROVIDER DEFINITION----------------------
provider "aws" {
    region     = var.AWS_REGION
    access_key = var.HOPETONMON_COPY_ACCESS_KEY
    secret_key = var.HOPETONMON_COPY_SECRET_KEY
  
}

provider "newrelic" {
  account_id = var.NEW_RELIC_ACCOUNT_ID
  api_key    = var.NEW_RELIC_API_KEY
  region     = "US" # or "EU" depending on your New Relic account
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
    cidr_block        = "10.0.0.0/24"
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
    subnet_id      = aws_subnet.web_subnet1.id  # Associate the route table with your subnet
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
    subnets            = [aws_subnet.web_subnet1.id, aws_subnet.web_subnet2.id]  
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

#-------------------LISTENER---------------------
resource "aws_lb_listener" "web_listener" {
    load_balancer_arn = aws_lb.web_alb.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.web_target_group.arn
    }

    tags = {
        Name = "web_listener"
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

#-------------------LAUNCH TEMPLATE---------------------
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-launch-template-"
  image_id      = "ami-0dba2cb6798deb6d8"
  instance_type = "t2.micro"
  key_name      = "car_key"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install nginx
    sudo apt update
    sudo apt install -y nginx
    echo "<h1>Hello from My (SCALED) Terraform Web Server!</h1><p>This is a Scaled Website running on an EC2 instance with user_data.</p>" | sudo tee /var/www/html/index.html
    sudo systemctl start nginx
    sudo systemctl enable nginx

    # Install New Relic Infrastructure Agent
    curl -Ls https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/newrelic-infra-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/newrelic-infra-archive-keyring.gpg] https://download.newrelic.com/infrastructure_agent/linux/apt focal main" | sudo tee /etc/apt/sources.list.d/newrelic-infra.list
    sudo apt update
    sudo apt install -y newrelic-infra

    # Configure with your New Relic license key
    echo "license_key: YOUR_NEW_RELIC_LICENSE_KEY" | sudo tee -a /etc/newrelic-infra.yml

    # Start and enable New Relic Infra Agent
    sudo systemctl enable newrelic-infra
    sudo systemctl start newrelic-infra
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "web_launch_template"
  }
}

#-------------------AUTO SCALING GROUP---------------------
resource "aws_autoscaling_group" "web_asg" {
    desired_capacity     = 1
    max_size             = 5
    min_size             = 1
    vpc_zone_identifier = [aws_subnet.web_subnet1.id, aws_subnet.web_subnet2.id]
    launch_template {
        id      = aws_launch_template.web_launch_template.id
        version = "$Latest"
    }
    tag {
        key                 = "Name"
        value               = "web_asg_instance"
        propagate_at_launch = true
    }
}

#-------------------AUTO SCALING POLICY---------------------
resource "aws_autoscaling_policy" "web_scale_up" {
    name                   = "web-scale-up"
    scaling_adjustment      = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
    autoscaling_group_name = aws_autoscaling_group.web_asg.name
}
resource "aws_autoscaling_policy" "web_scale_down" {
    name                   = "web-scale-down"
    scaling_adjustment      = -1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
    autoscaling_group_name = aws_autoscaling_group.web_asg.name
}


#-------------------DATA-------------------------
data "aws_instances" "web_instances" {
  filter {
    name   = "tag:Name"
    values = ["web_asg_instance"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_autoscaling_group.web_asg]
}

#-------------------OUTPUTS---------------------
output "web_instance_public_ips" { #After running terraform apply, Terraform will display the output values directly in the console. Additionally, you can view all outputs later by running: terraform apply
  description = "Public IPs of EC2 instances in the ASG"
  value       = data.aws_instances.web_instances.public_ips
}

output "web_instance_private_ips" {
  description = "Private IPs of EC2 instances in the ASG"
  value       = data.aws_instances.web_instances.private_ips
}


#-------------------NEW RELIC MONITORING---------------------
resource "newrelic_infra_agent" "web_infra_agent" { #This resource is very important. It installs the New Relic Infrastructure Agent on the EC2 instances to monitor their performance and health.
  name = "web_infra_agent"
  description = "New Relic Infrastructure Agent for Web App"
  enabled = true
  tags = {
    environment = "production"
    role        = "web_server"
  }
}

resource "newrelic_alert_policy" "web_app_policy" {
  name = "Web App Alert Policy"
}

resource "newrelic_nrql_alert_condition" "high_cpu_alert" {
  policy_id = newrelic_alert_policy.web_app_policy.id
  name      = "High CPU Usage"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT average(cpuPercent) FROM SystemSample WHERE `host.hostname` LIKE '%web%' FACET `host.hostname`"
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 300  # 5 minutes
    threshold_occurrences = "ALL"
  }
}
