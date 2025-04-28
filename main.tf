terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
        }
    }
    
    required_version = ">= 1.0.0"
}

#-----------------------VARIABLES-----------------------------
variable "TERRY_ACCESS_KEY" {
    description = "Terry's AWS Access Key"
    type        = string
    sensitive = true
}

variable "TERRY_SECRET_KEY" {
    description = "Terry's AWS Secret Key"
    type        = string
    sensitive = true
  
}

variable "AWS_REGION" {
    description = "AWS Region"
    type        = string
}

variable "AVALABILITY_ZONE" {
    description = "Availability Zone (Distinct loaction in the Region)"
    type        = string
}

#------------------PROVIDERS----------------------
provider "aws" {
    region     = var.AWS_REGION
    access_key = var.TERRY_ACCESS_KEY
    secret_key = var.TERRY_SECRET_KEY
  
}

#-------------------VPC---------------------
resource "aws_vpc" "web_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "web_vpc"
    }
}

#-------------------SUBNETS---------------------
resource "aws_subnet" "web_subnet" {
    vpc_id            = aws_vpc.web_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone =  var.AVALABILITY_ZONE
    map_public_ip_on_launch = true #If set to true: Instances launched in this subnet will automatically be assigned a public IP address. This is useful for subnets that need to host publicly accessible resources, such as web servers.
    tags = {
        Name = "web_subnet"
    }
}

#-------------------INTERNET GATEWAY---------------------
resource "aws_internet_gateway" "web_igw" {
    vpc_id = aws_vpc.web_vpc.id
    tags = {
        Name = "web_igw"
    }
}
