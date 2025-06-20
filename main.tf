#-------------PROVIDER CONFIGURATION---------------------
terraform {
  required_version = ">= 1.0.0"

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
}

variable "NEW_RELIC_LICENSE_KEY" {
  description = "New Relic License Key"
  type        = string
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
    enable_dns_hostnames = true # Enables or disables the assignment of public DNS hostnames to instances launched in the VPC.
    tags = {
        Name = "web_vpc"
    }
}

#-------------------SUBNETS---------------------
resource "aws_subnet" "public_subnet1" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone =  var.AVAILABILITY_ZONE
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "public_subnet1"
    }
}

resource "aws_subnet" "public_subnet2" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.2.0/24"
    availability_zone = var.AVAILABILITY_ZONE2
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "public_subnet2"
    }
  
}

resource "aws_subnet" "private_subnet1" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.3.0/24"
    availability_zone = var.AVAILABILITY_ZONE
    map_public_ip_on_launch = false #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "private_subnet1"
    }
  
}

resource "aws_subnet" "private_subnet2" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.4.0/24"
    availability_zone = var.AVAILABILITY_ZONE2
    map_public_ip_on_launch = false #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "private_subnet2"
    }
}


#-------------------INTERNET GATEWAY---------------------
resource "aws_internet_gateway" "web_igw" {
    vpc_id = aws_vpc.web_vpc.id
    tags = {
        Name = "web_igw"
    }
}

#-------------------NAT GATEWAY---------------------
resource "aws_eip" "nat_eip1" {
    # When you create a NAT Gateway, it needs a public IP address to send traffic out to the internet. That’s where this Elastic IP comes in
    tags = {
        Name = "nat_eip1"
    }
}

resource "aws_eip" "nat_eip2" {
    tags = {
        Name = "nat_eip2"
    }
}
resource "aws_nat_gateway" "nat_gateway1" {
    allocation_id = aws_eip.nat_eip1.id
    subnet_id     = aws_subnet.public_subnet1.id # NAT Gateway must be in a public subnet
    tags = {
        Name = "nat_gateway1"
    }
}

resource "aws_nat_gateway" "nat_gateway2" {
    allocation_id = aws_eip.nat_eip2.id
    subnet_id     = aws_subnet.public_subnet2.id # NAT Gateway must be in a public subnet
    tags = {
        Name = "nat_gateway2"
    }
}

#-------------------ROUTE TABLE---------------------
resource "aws_route_table" "igw_route_table" {
    vpc_id = aws_vpc.web_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.web_igw.id
  
}
    tags = {
        Name = "igw_route_table"
    }
}

resource "aws_route_table" "nat_route_table1" {
    vpc_id = aws_vpc.web_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway1.id
  
}
    tags = {
        Name = "nat_route_table1"
    }
}

resource "aws_route_table" "nat_route_table2" {
    vpc_id = aws_vpc.web_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway2.id
}
    tags = {
        Name = "nat_route_table2"
    }
}

#-------------------ROUTE TABLE ASSOCIATION---------------------
resource "aws_route_table_association" "public_subnet1_route_table_assoc" {
    subnet_id      = aws_subnet.public_subnet1.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_route_table_association" "public_subnet2_route_table_assoc" {
    subnet_id      = aws_subnet.public_subnet2.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.igw_route_table.id
}

resource "aws_route_table_association" "private_subnet1_route_table_assoc" {
    subnet_id      = aws_subnet.private_subnet1.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.nat_route_table1.id
}

resource "aws_route_table_association" "private_subnet2_route_table_assoc" {
    subnet_id      = aws_subnet.private_subnet2.id  # Associate the route table with your subnet
    route_table_id = aws_route_table.nat_route_table2.id
}

#-------------------LOAD BALANCER---------------------
resource "aws_lb" "web_alb" {
    name               = "web-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]  
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
        cidr_blocks = ["0.0.0.0/0"] #Allow HTTP traffic from anywhere
    } 
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allow SSH traffic from any(where
    }
    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"] #Allow HTTPS traffic from anywhere
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1" #Allow all outbound traffic with any protocol
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
    ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
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

  vpc_security_group_ids = [aws_security_group.web_sg.id]


  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    new_relic_license_key = var.NEW_RELIC_LICENSE_KEY
  }))

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "instance"
  }
}

#-------------------AUTO SCALING GROUP---------------------
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 1
  max_size             = 5
  min_size             = 1
  vpc_zone_identifier = [
    aws_subnet.private_subnet1.id,
    aws_subnet.private_subnet2.id
  ]

  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_target_group.arn] #This line associates the Auto Scaling Group with the ALB Target Group, allowing the ALB to route traffic to instances in the ASG.

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

  depends_on = [aws_autoscaling_group.web_asg] #This tells Terraform: “Wait until the Auto Scaling Group (web_asg) is created before trying to query EC2 instances using the aws_instances data block.”
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

output "alb_dns_name" { #This output will show the DNS name of the Application Load Balancer (ALB) created in the VPC. We use this DNS name to access our web application.
  value = aws_lb.web_alb.dns_name 
}

output "vpc_id" {
  value = aws_vpc.web_vpc.id
}

output "nat_gateway1_ip" {
  value = aws_eip.nat_eip1.public_ip
}
output "nat_gateway2_ip" {
  value = aws_eip.nat_eip2.public_ip
}


#-------------------NEW RELIC MONITORING---------------------

module "newrelic_aws_integration" { #This module sets up the New Relic AWS integration to monitor AWS resources.
  source = "github.com/newrelic/terraform-provider-newrelic//examples/modules/cloud-integrations/aws"

  newrelic_account_id     = var.NEW_RELIC_ACCOUNT_ID
  newrelic_account_region = "US"
  name                    = "production"

  include_metric_filters = {
    "AWS/EC2" = [], # includes ALL EC2 metrics
    "AWS/ELB" = [], # includes ALL ELB metrics
    "AWS/AutoScaling" = [], # includes ALL Auto Scaling metrics}
  }
}

#-------------------NEW RELIC ALERTS---------------------

resource "newrelic_alert_policy" "web_app_policy" { #Creates an alert policy (a container/folder for alerts)

 name = "Web App Alert Policy"
}

resource "newrelic_alert_channel" "email_channel" { #Creates an alert channel to send email notifications when alerts are triggered
  account_id = var.NEW_RELIC_ACCOUNT_ID
  name = "Email Alerts"
  type = "email"

  config {
    recipients = "hopetonmon@gmail.com" #Replace with your email address
    include_json_attachment = "true"
  }
}

resource "newrelic_alert_policy_channel" "policy_email_link" { #Links the alert policy to the email alert channel
  account_id = var.NEW_RELIC_ACCOUNT_ID
  policy_id   = newrelic_alert_policy.web_app_policy.id
  channel_ids = [newrelic_alert_channel.email_channel.id]
}



resource "newrelic_nrql_alert_condition" "high_cpu_alert" { #	Creates an alert rule that watches CPU usage above 80% for 5 minutes on web hosts
  policy_id = newrelic_alert_policy.web_app_policy.id
  name      = "High CPU Usage"
  type      = "static"
  enabled   = true

  nrql {
    query = "SELECT average(cpuPercent) FROM SystemSample FACET `host.hostname`" #This query monitors the average CPU percentage of all hosts in the system.
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 300  # 5 minutes
    threshold_occurrences = "ALL"
  }
}
